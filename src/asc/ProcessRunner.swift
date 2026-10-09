//
//  ProcessRunner.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// Runs a system tool and collects its output.
enum ProcessRunner {
    struct Result {
        let status: Int32
        let stdout: Data
        let stderr: Data
        let isTimedOut: Bool

        /// `nil` if the tool exited with status 0 in time, otherwise why it failed.
        var failureMessage: String? {
            if self.isTimedOut {
                return "timed out"
            }
            guard self.status != 0 else {
                return nil
            }
            return String(decoding: self.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func run(
        _ executableURL: URL,
        arguments: [String],
        input: Data? = nil,
        timeout: TimeInterval
    ) throws
        -> Result
    {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdout = PipeCollector()
        let stderr = PipeCollector()
        let stdinPipe = Pipe()
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe
        process.standardInput = input == nil ? FileHandle.nullDevice : stdinPipe

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        try process.run()

        if let input {
            DispatchQueue.global().async {
                try? stdinPipe.fileHandleForWriting.write(contentsOf: input)
                try? stdinPipe.fileHandleForWriting.close()
            }
        }

        let isTimedOut = exited.wait(timeout: .now() + timeout) == .timedOut
        if isTimedOut {
            process.terminate()
            exited.wait()
        }

        return Result(
            status: process.terminationStatus,
            stdout: stdout.finish(),
            stderr: stderr.finish(),
            isTimedOut: isTimedOut
        )
    }
}

/// Collects a pipe's output as it arrives. `finish()` doesn't wait for EOF indefinitely, because a grandchild
/// (such as `op daemon`) may inherit the pipe and keep it open.
private final class PipeCollector: @unchecked Sendable {
    let pipe = Pipe()
    private let lock = NSLock()
    private let closed = DispatchSemaphore(value: 0)
    private var data = Data()

    init() {
        self.pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else {
                return
            }
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                self.closed.signal()
            } else {
                self.lock.withLock { self.data.append(chunk) }
            }
        }
    }

    func finish() -> Data {
        _ = self.closed.wait(timeout: .now() + 2)
        self.pipe.fileHandleForReading.readabilityHandler = nil
        return self.lock.withLock { self.data }
    }
}

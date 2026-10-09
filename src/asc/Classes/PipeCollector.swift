//
//  PipeCollector.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// Collects a pipe's output as it arrives. `finish()` doesn't wait for EOF indefinitely, because a grandchild
/// (such as `op daemon`) may inherit the pipe and keep it open.
final class PipeCollector: @unchecked Sendable {
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

    // MARK: Public

    func finish() -> Data {
        _ = self.closed.wait(timeout: .now() + 2)
        self.pipe.fileHandleForReading.readabilityHandler = nil
        return self.lock.withLock { self.data }
    }
}

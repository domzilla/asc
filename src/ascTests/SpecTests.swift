//
//  SpecTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CryptoKit
import Foundation
import os
import Testing
@testable import asc

@Suite("Spec gate")
struct SpecTests {
    /// Nothing listens on port 1, so every download fails fast without touching the network.
    static let unreachableURL = URL(string: "http://127.0.0.1:1/spec.zip")!
    static let specData = Data(#"{"info":{"version":"9.9.9"},"paths":{}}"#.utf8)
    static let specSHA256 = SHA256.hash(data: Self.specData).map { String(format: "%02x", $0) }.joined()

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("asc-spec-test-\(UUID().uuidString)")

    func spec(reviewedVersion: String = "9.9.9", reviewedSHA256: String = Self.specSHA256) -> Spec {
        Spec(
            cacheDirectory: self.directory,
            downloadURL: Self.unreachableURL,
            reviewedVersion: reviewedVersion,
            reviewedSHA256: reviewedSHA256
        )
    }

    /// Writes the cached spec and backdates the last check by `age`.
    func cache(checkedAgo age: TimeInterval) throws {
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        try Self.specData.write(to: self.directory.appendingPathComponent("openapi.oas.json"))
        let checkURL = self.directory.appendingPathComponent("last-check")
        try Data().write(to: checkURL)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-age)],
            ofItemAtPath: checkURL.path
        )
    }

    static func isSpecGateError(_ error: any Error) -> Bool {
        guard case .specGate = error as? ASCError else {
            return false
        }
        return true
    }

    static func isSpecChangedError(_ error: any Error) -> Bool {
        guard case let .specGate(message) = error as? ASCError else {
            return false
        }
        return message.hasPrefix("Apple's API spec changed")
    }

    @Test("A recently checked, reviewed spec allows writes without downloading")
    func allowsFreshReviewedSpec() async throws {
        defer { try? FileManager.default.removeItem(at: self.directory) }
        try self.cache(checkedAgo: 60 * 60)

        try await self.spec().ensureWritesAllowed()
    }

    @Test("Writes are refused when the stale spec can't be re-checked, even though the cached copy is reviewed")
    func refusesWhenStaleCheckFails() async throws {
        defer { try? FileManager.default.removeItem(at: self.directory) }
        try self.cache(checkedAgo: Spec.checkInterval + 60)

        await #expect(performing: {
            try await self.spec().ensureWritesAllowed()
        }, throws: Self.isSpecGateError)
        #expect(try Data(contentsOf: self.directory.appendingPathComponent("openapi.oas.json")) == Self.specData)
    }

    @Test("Writes are refused when there is no cached spec and the download fails")
    func refusesWithoutCacheWhenDownloadFails() async {
        defer { try? FileManager.default.removeItem(at: self.directory) }

        await #expect(performing: {
            try await self.spec().ensureWritesAllowed()
        }, throws: Self.isSpecGateError)
    }

    @Test("Writes are refused because the spec changed when the cached spec's SHA-256 differs from the reviewed one")
    func refusesUnreviewedSHA256() async throws {
        defer { try? FileManager.default.removeItem(at: self.directory) }
        try self.cache(checkedAgo: 60)

        await #expect(performing: {
            try await self.spec(reviewedSHA256: String(repeating: "0", count: 64)).ensureWritesAllowed()
        }, throws: Self.isSpecChangedError)
    }

    @Test("Writes are refused because the spec changed when the cached spec's version differs from the reviewed one")
    func refusesUnreviewedVersion() async throws {
        defer { try? FileManager.default.removeItem(at: self.directory) }
        try self.cache(checkedAgo: 60)

        await #expect(performing: {
            try await self.spec(reviewedVersion: "9.9.8").ensureWritesAllowed()
        }, throws: Self.isSpecChangedError)
    }

    @Test("Lookups fall back to the cached spec when the due check fails")
    func documentUsesCacheWhenCheckFails() async throws {
        defer { try? FileManager.default.removeItem(at: self.directory) }
        try self.cache(checkedAgo: Spec.checkInterval + 60)

        let document = try await self.spec().document()
        #expect((document["info"] as? [String: Any])?["version"] as? String == "9.9.9")
    }

    @Test("Lookups fail when there is no cached spec and the download fails")
    func documentFailsWithoutCache() async {
        defer { try? FileManager.default.removeItem(at: self.directory) }

        await #expect(throws: URLError.self) {
            try await self.spec().document()
        }
    }

    @Test("A forced check fails when the download fails, even with a fresh cache")
    func forcedCheckFails() async throws {
        defer { try? FileManager.default.removeItem(at: self.directory) }
        try self.cache(checkedAgo: 60)

        await #expect(throws: URLError.self) {
            try await self.spec().status(forceCheck: true)
        }
    }

    @Test("Concurrent checks while one is due share a single download and its result")
    func concurrentChecksDownloadOnce() async throws {
        let check = Spec.Check()
        let downloads = OSAllocatedUnfairLock(initialState: 0)
        let isDue = OSAllocatedUnfairLock(initialState: true)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await check.run(force: false, isDue: { isDue.withLock { $0 } }, download: {
                        downloads.withLock { $0 += 1 }
                        await Task.yield()
                        isDue.withLock { $0 = false }
                    })
                }
            }
            try await group.waitForAll()
        }

        #expect(downloads.withLock { $0 } == 1)
    }
}

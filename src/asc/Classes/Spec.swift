//
//  Spec.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CryptoKit
import Foundation

/// Apple's App Store Connect OpenAPI spec. Writes are only allowed while Apple's latest spec is exactly the one the
/// blocklist was reviewed against, so new endpoints can't slip through unreviewed.
struct Spec {
    /// Bump both only after reviewing the new spec's write endpoints against `Blocklist`.
    static let reviewedVersion = "4.5.1"
    static let reviewedSHA256 = "7518d3a94a8bd701ac25c1c601b95b8f53aad92091affb15a2a9d331713dac1a"

    static let checkInterval: TimeInterval = 24 * 60 * 60
    static let specFileName = "openapi.oas.json"
    static let checkFileName = "last-check"

    static let shared = Spec(
        cacheDirectory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("asc"),
        downloadURL: URL(
            string: "https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip"
        )!,
        reviewedVersion: Self.reviewedVersion,
        reviewedSHA256: Self.reviewedSHA256
    )

    /// Runs at most one check at a time, so concurrent agent requests share one download and its result.
    actor Check {
        private var inFlight: Task<Void, any Error>?

        func run(
            shouldForce: Bool,
            isDue: @Sendable () -> Bool,
            download: @escaping @Sendable () async throws -> Void
        ) async throws {
            if let inFlight = self.inFlight {
                return try await inFlight.value
            }
            guard shouldForce || isDue() else {
                return
            }
            let task = Task { try await download() }
            self.inFlight = task
            defer { self.inFlight = nil }
            try await task.value
        }
    }

    struct Status {
        let version: String
        let sha256: String
        let checkedAt: Date
    }

    let cacheDirectory: URL
    let downloadURL: URL
    let reviewedVersion: String
    let reviewedSHA256: String
    let check = Check()

    private var specURL: URL {
        self.cacheDirectory.appendingPathComponent(Self.specFileName)
    }

    private var checkURL: URL {
        self.cacheDirectory.appendingPathComponent(Self.checkFileName)
    }

    // MARK: Public

    func isReviewed(_ status: Status) -> Bool {
        status.version == self.reviewedVersion && status.sha256 == self.reviewedSHA256
    }

    func ensureWritesAllowed() async throws {
        let status: Status
        do {
            status = try await self.status()
        } catch {
            throw ASCError.specGate("couldn't check Apple's API spec for updates (\(error))")
        }
        guard self.isReviewed(status) else {
            throw ASCError.specGate(
                "Apple's API spec changed (reviewed \(self.reviewedVersion) \(self.reviewedSHA256.prefix(12)), "
                    + "latest \(status.version) \(status.sha256.prefix(12))). The user must review the new write "
                    + "endpoints against the blocklist and update Spec.reviewedVersion/reviewedSHA256."
            )
        }
    }

    func status(shouldForceCheck: Bool = false) async throws -> Status {
        try await self.checkIfDue(shouldForce: shouldForceCheck)
        let data = try Data(contentsOf: self.specURL)
        let checkedAt = try FileManager.default.attributesOfItem(atPath: self.checkURL.path)[.modificationDate] as? Date
        return try Status(
            version: self.version(of: data),
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            checkedAt: checkedAt ?? .distantPast
        )
    }

    /// Lookups aren't gated, so a failed check falls back to the cached spec.
    func document() async throws -> [String: Any] {
        do {
            try await self.checkIfDue(shouldForce: false)
        } catch where FileManager.default.fileExists(atPath: self.specURL.path) {}
        let data = try Data(contentsOf: self.specURL)
        guard let document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ASCError.failure("the cached spec is not a JSON object")
        }
        return document
    }

    // MARK: Private

    private var isCheckDue: Bool {
        let manager = FileManager.default
        guard
            manager.fileExists(atPath: self.specURL.path),
            let checkedAt = try? manager.attributesOfItem(atPath: self.checkURL.path)[.modificationDate] as? Date else
        {
            return true
        }
        return Date().timeIntervalSince(checkedAt) > Self.checkInterval
    }

    private func checkIfDue(shouldForce: Bool) async throws {
        try await self.check.run(
            shouldForce: shouldForce,
            isDue: { self.isCheckDue },
            download: { try await self.download() }
        )
    }

    private func download() async throws {
        let (zip, response) = try await APIClient.session.data(from: self.downloadURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ASCError.failure("downloading the spec failed with \(response)")
        }

        let manager = FileManager.default
        try manager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        let zipURL = self.cacheDirectory.appendingPathComponent("download-\(UUID().uuidString).zip")
        try zip.write(to: zipURL, options: .atomic)
        defer { try? manager.removeItem(at: zipURL) }

        let result = try ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/unzip"),
            arguments: ["-p", zipURL.path, Self.specFileName],
            timeout: 60
        )
        if let message = result.failureMessage {
            throw ASCError.failure("unzipping the spec failed: \(message)")
        }
        _ = try self.version(of: result.stdout)

        try result.stdout.write(to: self.specURL, options: .atomic)
        try Data().write(to: self.checkURL, options: .atomic)
    }

    private func version(of data: Data) throws -> String {
        guard
            let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let info = document["info"] as? [String: Any],
            let version = info["version"] as? String else
        {
            throw ASCError.failure("the spec has no info.version")
        }
        return version
    }
}

//
//  OnePassword.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Security

/// The 1Password CLI. Resolved from fixed locations and verified to be signed by AgileBits, so a planted `op` earlier
/// in PATH can't intercept the key.
struct OnePassword {
    private static let candidatePaths = ["/opt/homebrew/bin/op", "/usr/local/bin/op"]
    private static let requirement = #"anchor apple generic and certificate leaf[subject.OU] = "2BUA8C4S2C""#
    private static let timeout: TimeInterval = 60

    private let executableURL: URL

    init() throws {
        for path in Self.candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            guard Self.isSignedByAgileBits(url) else {
                throw ASCError.credentials("\(path) is not signed by 1Password (AgileBits); refusing to use it")
            }
            self.executableURL = url
            return
        }
        throw ASCError.credentials("1Password CLI not found at \(Self.candidatePaths.joined(separator: " or "))")
    }

    // MARK: Public

    func read(_ reference: String) throws -> String {
        let result = try ProcessRunner.run(
            self.executableURL,
            arguments: ["read", "--no-newline", reference],
            timeout: Self.timeout
        )
        if result.isTimedOut {
            throw ASCError.credentials(
                "1Password didn't answer within \(Int(Self.timeout))s. The 1Password app must be open and unlocked, "
                    + "and the access prompt approved."
            )
        }
        if let message = result.failureMessage {
            throw ASCError.credentials("op read \(reference) failed: \(message)")
        }
        return String(decoding: result.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Private

    private static func isSignedByAgileBits(_ url: URL) -> Bool {
        var staticCode: SecStaticCode?
        var requirement: SecRequirement?
        guard
            SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
            SecRequirementCreateWithString(self.requirement as CFString, [], &requirement) == errSecSuccess,
            let staticCode,
            let requirement else
        {
            return false
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
    }
}

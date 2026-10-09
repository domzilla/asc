//
//  Credentials.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Security

/// An App Store Connect API key, loaded from a 1Password item that has the fields `key_id`, `issuer_id`,
/// optionally `vendor_number`, and the attached file `AuthKey_<key_id>.p8`.
struct Credentials: Codable, CustomStringConvertible {
    let keyID: String
    let issuerID: String
    let vendorNumber: String?
    let privateKeyPEM: String

    var description: String {
        "Credentials(keyID: \(self.keyID), issuerID: \(self.issuerID), privateKey: <redacted>)"
    }

    static func load(from itemReference: String) throws -> Credentials {
        let item = try self.validatedItemReference(itemReference)
        let op = try OnePassword()

        let keyID = try op.read("\(item)/key_id")
        guard keyID.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else {
            throw ASCError.credentials("key_id must be 10 uppercase letters or digits")
        }
        let issuerID = try op.read("\(item)/issuer_id")
        guard UUID(uuidString: issuerID) != nil else {
            throw ASCError.credentials("issuer_id must be a UUID")
        }
        let privateKeyPEM = try op.read("\(item)/AuthKey_\(keyID).p8")
        // Optional: only sales and finance report requests need it.
        let vendorNumber = try? op.read("\(item)/vendor_number")

        return Credentials(keyID: keyID, issuerID: issuerID, vendorNumber: vendorNumber, privateKeyPEM: privateKeyPEM)
    }

    static func validatedItemReference(_ reference: String) throws -> String {
        let pattern = "^op://[^/]+/[^/]+$"
        guard reference.range(of: pattern, options: .regularExpression) != nil else {
            throw ASCError.credentials("expected a 1Password item reference like op://Vault/Item, got '\(reference)'")
        }
        return reference
    }
}

/// The 1Password CLI. Resolved from fixed locations and verified to be signed by AgileBits, so a planted `op` earlier
/// in PATH can't intercept the key.
private struct OnePassword {
    static let candidatePaths = ["/opt/homebrew/bin/op", "/usr/local/bin/op"]
    static let requirement = #"anchor apple generic and certificate leaf[subject.OU] = "2BUA8C4S2C""#
    static let timeout: TimeInterval = 60

    let executableURL: URL

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
        guard result.status == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw ASCError.credentials("op read \(reference) failed: \(message)")
        }
        return String(decoding: result.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

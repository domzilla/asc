//
//  Credentials.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// An App Store Connect API key, loaded from a 1Password item that has the fields `key_id`, `issuer_id`,
/// optionally `vendor_number`, and the attached file `AuthKey_<key_id>.p8`.
struct Credentials: Codable, CustomStringConvertible {
    struct KeyID: Codable {
        let rawValue: String
    }

    struct IssuerID: Codable {
        let rawValue: String
    }

    let keyID: KeyID
    let issuerID: IssuerID
    let vendorNumber: String?
    let privateKeyPEM: String

    static let referencePlaceholder = "op://Vault/Item"

    var description: String {
        "Credentials(keyID: \(self.keyID.rawValue), issuerID: \(self.issuerID.rawValue), privateKey: <redacted>)"
    }

    // MARK: Public

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

        return Credentials(
            keyID: KeyID(rawValue: keyID),
            issuerID: IssuerID(rawValue: issuerID),
            vendorNumber: vendorNumber,
            privateKeyPEM: privateKeyPEM
        )
    }

    static func validatedItemReference(_ reference: String) throws -> String {
        let pattern = "^op://[^/]+/[^/]+$"
        guard reference.range(of: pattern, options: .regularExpression) != nil else {
            throw ASCError.credentials(
                "expected a 1Password item reference like \(self.referencePlaceholder), got '\(reference)'"
            )
        }
        return reference
    }
}

//
//  JWT.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CryptoKit
import Foundation

enum JWT {
    /// Apple rejects tokens that live longer than 20 minutes.
    static let lifetime: TimeInterval = 15 * 60

    // MARK: Public

    static func token(for credentials: Credentials, now: Date = Date()) throws -> String {
        let key: P256.Signing.PrivateKey
        do {
            key = try P256.Signing.PrivateKey(pemRepresentation: credentials.privateKeyPEM)
        } catch {
            throw ASCError.credentials("the private key is not a valid P-256 PEM key")
        }

        let issuedAt = Int(now.timeIntervalSince1970)
        let header: [String: Any] = ["alg": "ES256", "kid": credentials.keyID.rawValue, "typ": "JWT"]
        let payload: [String: Any] = [
            "aud": "appstoreconnect-v1",
            "exp": issuedAt + Int(self.lifetime),
            "iat": issuedAt,
            "iss": credentials.issuerID.rawValue,
        ]

        let signingInput = try self.base64URL(self.json(header)) + "." + self.base64URL(self.json(payload))
        let signature = try key.signature(for: Data(signingInput.utf8))
        return signingInput + "." + self.base64URL(signature.rawRepresentation)
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: Private

    private static func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

//
//  JWTTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import CryptoKit
import Foundation
import Testing
@testable import asc

@Suite("JWT")
struct JWTTests {
    static func decode(_ part: Substring) throws -> Data {
        var base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return try #require(Data(base64Encoded: base64))
    }

    @Test("The token has Apple's required header and claims and a valid ES256 signature")
    func tokenIsValid() throws {
        let key = P256.Signing.PrivateKey()
        let credentials = Credentials(
            keyID: Credentials.KeyID(rawValue: "ABCDE12345"),
            issuerID: Credentials.IssuerID(rawValue: "00000000-1111-2222-3333-444444444444"),
            vendorNumber: nil,
            privateKeyPEM: key.pemRepresentation
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let token = try JWT.token(for: credentials, now: now)
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        try #require(parts.count == 3)
        #expect(!token.contains("="))

        let header = try #require(JSONSerialization.jsonObject(with: Self.decode(parts[0])) as? [String: Any])
        #expect(header["alg"] as? String == "ES256")
        #expect(header["kid"] as? String == "ABCDE12345")
        #expect(header["typ"] as? String == "JWT")

        let payload = try #require(JSONSerialization.jsonObject(with: Self.decode(parts[1])) as? [String: Any])
        #expect(payload["iss"] as? String == "00000000-1111-2222-3333-444444444444")
        #expect(payload["aud"] as? String == "appstoreconnect-v1")
        #expect(payload["iat"] as? Int == 1_800_000_000)
        #expect(payload["exp"] as? Int == 1_800_000_900)

        let signature = try P256.Signing.ECDSASignature(rawRepresentation: Self.decode(parts[2]))
        #expect(key.publicKey.isValidSignature(signature, for: Data("\(parts[0]).\(parts[1])".utf8)))
    }

    @Test("The token lives less than Apple's 20-minute maximum")
    func lifetimeIsBelowAppleMaximum() {
        #expect(JWT.lifetime < 20 * 60)
    }

    @Test("A key that isn't a P-256 PEM key is a credentials error that doesn't echo the key")
    func rejectsInvalidKey() {
        let credentials = Credentials(
            keyID: Credentials.KeyID(rawValue: "ABCDE12345"),
            issuerID: Credentials.IssuerID(rawValue: UUID().uuidString),
            vendorNumber: nil,
            privateKeyPEM: "SECRET-NOT-A-KEY"
        )
        #expect {
            try JWT.token(for: credentials)
        } throws: { error in
            guard let error = error as? ASCError, case .credentials = error else {
                return false
            }
            return !error.description.contains("SECRET")
        }
    }

    @Test("Credentials never print the private key")
    func credentialsRedactKey() {
        let credentials = Credentials(
            keyID: Credentials.KeyID(rawValue: "ABCDE12345"),
            issuerID: Credentials.IssuerID(rawValue: "issuer"),
            vendorNumber: nil,
            privateKeyPEM: "SECRET"
        )
        #expect(!"\(credentials)".contains("SECRET"))
        #expect(!String(reflecting: credentials).contains("SECRET"))
    }

    @Test(
        "Only plain 1Password item references are accepted",
        arguments: ["op://ASC/Item", "op://Vault/Item With Spaces - Admin"]
    )
    func acceptsItemReference(_ reference: String) throws {
        #expect(try Credentials.validatedItemReference(reference) == reference)
    }

    @Test(
        "Field references, missing parts and other schemes are rejected",
        arguments: ["op://ASC/Item/key_id", "op://ASC", "ASC/Item", "op:///Item", "file://ASC/Item"]
    )
    func rejectsItemReference(_ reference: String) {
        #expect(throws: ASCError.self) {
            try Credentials.validatedItemReference(reference)
        }
    }
}

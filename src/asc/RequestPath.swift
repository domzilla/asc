//
//  RequestPath.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// A validated API path plus query. The path is kept strict (no percent-encoding, no dot segments) so the
/// blocklist sees exactly the resource the server will act on.
struct RequestPath: Equatable {
    static let host = "api.appstoreconnect.apple.com"

    let path: String
    let queryItems: [URLQueryItem]

    var segments: [Substring] {
        self.path.split(separator: "/")
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = self.path
        if !self.queryItems.isEmpty {
            components.percentEncodedQueryItems = self.queryItems.map {
                URLQueryItem(name: Self.encode($0.name), value: $0.value.map(Self.encode))
            }
        }
        return components.url!
    }

    /// Stricter than URLComponents' default, which leaves `+` unencoded.
    private static func encode(_ string: String) -> String {
        let unreserved =
            CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return string.addingPercentEncoding(withAllowedCharacters: unreserved)!
    }

    /// Accepts `/v1/apps?limit=200` or a full `https://api.appstoreconnect.apple.com/...` URL, such as a
    /// pagination link.
    init(_ raw: String) throws {
        var remainder = Substring(raw)
        let prefix = "https://\(Self.host)/"
        if raw.hasPrefix("https://") || raw.hasPrefix("http://") {
            guard raw.hasPrefix(prefix) else {
                throw ASCError.invalidPath("only https://\(Self.host) is allowed")
            }
            remainder = raw.dropFirst(prefix.count - 1)
        }
        guard !remainder.contains("#") else {
            throw ASCError.invalidPath("fragments are not allowed")
        }

        let parts = remainder.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(parts[0])
        guard path.range(of: "^/v[0-9]+(/[A-Za-z0-9_.-]+)+$", options: .regularExpression) != nil else {
            throw ASCError.invalidPath("'\(path)' must look like /v1/resource[/id...] using only A-Z, a-z, 0-9, _ . -")
        }
        guard !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw ASCError.invalidPath("dot segments are not allowed")
        }
        self.path = path
        self.queryItems = parts.count > 1 ? try Self.queryItems(String(parts[1])) : []
    }

    private static func queryItems(_ query: String) throws -> [URLQueryItem] {
        try query.split(separator: "&").map { pair in
            let nameValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let name = String(nameValue[0]).removingPercentEncoding, !name.isEmpty else {
                throw ASCError.invalidPath("malformed query parameter '\(pair)'")
            }
            var value: String?
            if nameValue.count > 1 {
                guard let decoded = String(nameValue[1]).removingPercentEncoding else {
                    throw ASCError.invalidPath("malformed query value in '\(pair)'")
                }
                value = decoded
            }
            return URLQueryItem(name: name, value: value)
        }
    }
}

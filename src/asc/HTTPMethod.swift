//
//  HTTPMethod.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// The only methods asc sends.
enum HTTPMethod: String, Codable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"

    /// Parses a command-line argument, ignoring case.
    init?(argument: String) {
        self.init(rawValue: argument.uppercased())
    }

    /// Everything but GET, so a method added later goes through the blocklist and spec gate (fail closed).
    var isWrite: Bool {
        self != .get
    }
}

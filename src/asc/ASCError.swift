//
//  ASCError.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

enum ASCError: Error, CustomStringConvertible {
    case usage(String)
    case invalidPath(String)
    case blocked(String)
    case specGate(String)
    case credentials(String)
    case agent(String)
    case agentNotRunning
    case api(status: Int, body: Data)
    case failure(String)

    /// Wraps errors from outside `asc` as `.failure`, so every error has an exit code.
    init(_ error: any Error) {
        self = error as? ASCError ?? .failure("\(error)")
    }

    /// Distinct exit codes let agents tell a refused request apart from an API error.
    var exitCode: Int32 {
        switch self {
        case .usage, .invalidPath:
            2
        case .blocked:
            3
        case .specGate:
            4
        case .credentials:
            5
        case .agent, .agentNotRunning:
            6
        case .api, .failure:
            1
        }
    }

    var description: String {
        switch self {
        case let .usage(message):
            message
        case let .invalidPath(message):
            "Invalid path: \(message)"
        case let .blocked(reason):
            "BLOCKED: \(reason). This operation is prohibited and was not sent."
        case let .specGate(message):
            "Writes disabled: \(message)"
        case let .credentials(message):
            "Credentials: \(message)"
        case let .agent(message):
            "Agent: \(message)"
        case .agentNotRunning:
            "Agent: no agent running; start one with `asc agent start --credentials <op://Vault/Item>`"
        case let .api(status, body):
            "HTTP \(status)\n\(String(decoding: body, as: UTF8.self))"
        case let .failure(message):
            message
        }
    }
}

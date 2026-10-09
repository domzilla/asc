//
//  ASC.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

@main
enum ASC {
    static let usage = """
    asc – App Store Connect API client with a built-in blocklist.

    USAGE
      asc --version
      asc agent start --credentials <\(Credentials.referencePlaceholder)> [--ttl <duration>]
      asc agent status
      asc agent stop
      asc <GET|POST|PATCH|DELETE> <path> [options]
      asc spec status [--check]
      asc spec find <term>...
      asc spec show <METHOD> <path>

    AGENT
      Requests go through a background agent that holds the API key in memory. Starting it reads the key from
      1Password (one approval). It stops after --ttl (default \(Int(Agent.defaultTTL / 60))m; e.g. 90s, 45m, 2h) or on `asc agent stop`.
      The 1Password item needs key_id, issuer_id, the attachment AuthKey_<key_id>.p8 and optionally vendor_number.

    REQUEST OPTIONS
      --body <file|->      JSON request body from a file or stdin (POST/PATCH/DELETE)
      --paginate           GET only: follow links.next and merge all pages
      --out <file>         Write the response to a file instead of stdout

    <path> is /v1/... with an optional query, or a full https://api.appstoreconnect.apple.com URL.
    Gzip responses (sales and finance reports) are decompressed.

    EXIT CODES
      0 ok · \(ASCError.failure("").exitCode) API or other error · \(ASCError.usage("").exitCode) usage · \
    \(ASCError.blocked("").exitCode) blocked · \(ASCError.specGate("").exitCode) writes disabled (spec changed) · \
    \(ASCError.credentials("").exitCode) credentials
      \(ASCError.agent("").exitCode) agent not running or failed
    """

    static func main() async {
        do {
            try await self.run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            let error = ASCError(error)
            self.writeError("asc: \(error)")
            exit(error.exitCode)
        }
    }

    // MARK: Private

    private static func run(_ arguments: [String]) async throws {
        guard let command = arguments.first else {
            throw ASCError.usage(self.usage)
        }
        switch command {
        case "-h", "--help", "help":
            self.write(self.usage + "\n")
        case "-v", "--version":
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            self.write("asc \(version ?? "unknown")\n")
        case "agent":
            try await self.runAgent(Array(arguments.dropFirst()))
        case "spec":
            try await self.runSpec(Array(arguments.dropFirst()))
        default:
            guard let method = HTTPMethod(argument: command) else {
                throw ASCError.usage("unknown command '\(command)'\n\n\(self.usage)")
            }
            try self.runRequest(method: method, Array(arguments.dropFirst()))
        }
    }

    private static func runAgent(_ arguments: [String]) async throws {
        switch arguments.first {
        case "start":
            var reference: String?
            var ttl = Agent.defaultTTL
            var iterator = arguments.dropFirst().makeIterator()
            while let argument = iterator.next() {
                switch argument {
                case "--credentials":
                    reference = try self.value(after: argument, &iterator)
                case "--ttl":
                    ttl = try Agent.parseTTL(self.value(after: argument, &iterator))
                default:
                    throw ASCError.usage("unexpected argument '\(argument)'")
                }
            }
            guard let reference else {
                throw ASCError.usage("missing --credentials <\(Credentials.referencePlaceholder)>")
            }
            try self.write(Agent.start(reference: reference, ttl: ttl) + "\n")
        case "status":
            try self.write((Agent.send(Agent.Request(command: .status)).message ?? "") + "\n")
        case "stop":
            // Stopping an agent that already expired is not an error.
            let response = try? Agent.send(Agent.Request(command: .stop))
            self.write((response?.message ?? "no agent running") + "\n")
        case "serve":
            try await Agent.serve()
        default:
            throw ASCError.usage("usage: asc agent start|status|stop")
        }
    }

    private static func runRequest(method: HTTPMethod, _ arguments: [String]) throws {
        var path: String?
        var bodySource: String?
        var outPath: String?
        var isPaginated = false

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--body":
                bodySource = try self.value(after: argument, &iterator)
            case "--out":
                outPath = try self.value(after: argument, &iterator)
            case "--paginate":
                isPaginated = true
            default:
                guard path == nil, !argument.hasPrefix("--") else {
                    throw ASCError.usage("unexpected argument '\(argument)'")
                }
                path = argument
            }
        }
        guard let path else {
            throw ASCError.usage("missing <path>")
        }

        let request = try Agent.Request(
            command: .request,
            method: method,
            path: path,
            body: bodySource.map(self.readBody),
            isPaginated: isPaginated
        )
        let response = try Agent.send(request)
        guard response.exitCode == 0 else {
            self.writeError("asc: \(response.message ?? "failed")")
            exit(response.exitCode)
        }

        let body = response.body ?? Data()
        if let outPath {
            try body.write(to: URL(fileURLWithPath: outPath), options: .atomic)
            self.writeError("asc: wrote \(body.count) bytes to \(outPath)")
        } else {
            FileHandle.standardOutput.write(body)
        }
    }

    private static func runSpec(_ arguments: [String]) async throws {
        switch arguments.first {
        case "status":
            let status = try await Spec.shared.status(shouldForceCheck: arguments.dropFirst().contains("--check"))
            self.write("""
            reviewed: \(Spec.reviewedVersion) \(Spec.reviewedSHA256)
            latest:   \(status.version) \(status.sha256)
            checked:  \(ISO8601DateFormatter().string(from: status.checkedAt))
            writes:   \(Spec.shared.isReviewed(status) ? "allowed" : "DISABLED until the new spec is reviewed")

            """)
        case "find":
            let terms = Array(arguments.dropFirst())
            guard !terms.isEmpty else {
                throw ASCError.usage("usage: asc spec find <term>...")
            }
            let lines = try await SpecLookup(document: Spec.shared.document()).find(terms)
            self.write(lines.isEmpty ? "no matches\n" : lines.joined(separator: "\n") + "\n")
        case "show":
            guard arguments.count == 3 else {
                throw ASCError.usage("usage: asc spec show <METHOD> <path>")
            }
            let lookup = try await SpecLookup(document: Spec.shared.document())
            try self.write(lookup.show(method: arguments[1], path: arguments[2]) + "\n")
        default:
            throw ASCError.usage("usage: asc spec status|find|show")
        }
    }

    private static func value(after option: String, _ iterator: inout some IteratorProtocol<String>) throws -> String {
        guard let value = iterator.next() else {
            throw ASCError.usage("\(option) needs a value")
        }
        return value
    }

    private static func readBody(_ source: String) throws -> Data {
        if source == "-" {
            return FileHandle.standardInput.readDataToEndOfFile()
        }
        // FileHandle also reads pipes such as `--body <(...)`, which Data(contentsOf:) refuses.
        guard let handle = FileHandle(forReadingAtPath: source) else {
            throw ASCError.usage("can't read --body \(source)")
        }
        defer { try? handle.close() }
        return try handle.readToEnd() ?? Data()
    }

    private static func write(_ string: String) {
        FileHandle.standardOutput.write(Data(string.utf8))
    }

    private static func writeError(_ string: String) {
        FileHandle.standardError.write(Data((string + "\n").utf8))
    }
}

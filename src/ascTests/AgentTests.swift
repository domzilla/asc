//
//  AgentTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation
import Testing
@testable import asc

@Suite("Agent")
struct AgentTests {
    @Test(
        "TTLs accept seconds, minutes and hours",
        arguments: [("90s", 90.0), ("30m", 1800.0), ("2h", 7200.0), ("1s", 1.0)]
    )
    func parsesTTL(_ input: String, _ expected: TimeInterval) throws {
        #expect(try Agent.parseTTL(input) == expected)
    }

    @Test("Malformed or non-positive TTLs are rejected", arguments: ["", "30", "m", "0m", "-5m", "1.5h", "2d", "1h30m"])
    func rejectsTTL(_ input: String) {
        #expect(throws: ASCError.self) {
            try Agent.parseTTL(input)
        }
    }

    @Test("The default TTL is 30 minutes")
    func defaultTTL() {
        #expect(Agent.defaultTTL == 30 * 60)
    }

    @Test("Messages larger than a pipe buffer survive a socket round trip, and the socket is private")
    func socketRoundTrip() throws {
        let directory = URL(fileURLWithPath: "/tmp/asc-test-\(getpid())-\(UInt32.random(in: 0...UInt32.max))")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("s.sock").path

        let listener = try UnixSocket.listen(at: path)
        defer { close(listener) }
        let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)

        let echo = Thread {
            let connection = accept(listener, nil, nil)
            guard connection >= 0 else {
                return
            }
            if UnixSocket.isSameUser(connection), let data = try? UnixSocket.readAll(connection) {
                try? UnixSocket.writeAll(connection, Data(data.reversed()))
            }
            close(connection)
        }
        echo.start()

        let message = Data((0..<1_000_000).map { UInt8($0 % 251) })
        let client = try UnixSocket.connect(to: path)
        defer { close(client) }
        try UnixSocket.writeAll(client, message)
        shutdown(client, SHUT_WR)
        #expect(try UnixSocket.readAll(client) == Data(message.reversed()))
    }

    @Test("Connecting without a listener reports that no agent is running")
    func connectWithoutAgent() {
        #expect(throws: ASCError.self) {
            try UnixSocket.connect(to: "/tmp/asc-test-missing-\(getpid()).sock")
        }
    }
}

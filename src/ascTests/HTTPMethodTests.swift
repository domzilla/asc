//
//  HTTPMethodTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Testing
@testable import asc

@Suite("HTTPMethod")
struct HTTPMethodTests {
    @Test("Every method except GET is a write")
    func isWrite() {
        #expect(!HTTPMethod.get.isWrite)
        #expect(HTTPMethod.post.isWrite)
        #expect(HTTPMethod.patch.isWrite)
        #expect(HTTPMethod.delete.isWrite)
    }

    @Test(
        "Arguments are parsed ignoring case",
        arguments: [("get", HTTPMethod.get), ("Patch", .patch), ("DELETE", .delete)]
    )
    func parsesArgument(_ argument: String, _ expected: HTTPMethod) {
        #expect(HTTPMethod(argument: argument) == expected)
    }

    @Test("Unsupported methods are rejected", arguments: ["PUT", "HEAD", "OPTIONS", "", "GETX"])
    func rejectsArgument(_ argument: String) {
        #expect(HTTPMethod(argument: argument) == nil)
    }
}

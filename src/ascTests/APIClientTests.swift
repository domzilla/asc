//
//  APIClientTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import asc

@Suite("APIClient")
struct APIClientTests {
    @Test("Gzip responses are decompressed")
    func decompressesGzip() throws {
        let report = Data("Provider\tSKU\tUnits\nAPPLE\tcom.example\t3\n".utf8)
        let gzip = try ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/gzip"),
            arguments: ["-c"],
            input: report,
            timeout: 10
        )
        try #require(gzip.status == 0)
        try #require(gzip.stdout.starts(with: [0x1F, 0x8B]))

        #expect(try APIClient.gunzipIfNeeded(gzip.stdout) == report)
    }

    @Test("Other responses pass through unchanged", arguments: [Data(), Data("{\"data\":[]}".utf8), Data([0x1F])])
    func passesThrough(_ data: Data) throws {
        #expect(try APIClient.gunzipIfNeeded(data) == data)
    }

    @Test("Corrupt gzip is an error")
    func rejectsCorruptGzip() {
        #expect(throws: ASCError.self) {
            try APIClient.gunzipIfNeeded(Data([0x1F, 0x8B, 0x00, 0x01]))
        }
    }
}

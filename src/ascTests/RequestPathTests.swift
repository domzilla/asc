//
//  RequestPathTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import asc

@Suite("RequestPath")
struct RequestPathTests {
    @Test("A plain path keeps its segments")
    func plainPath() throws {
        let path = try RequestPath("/v1/apps/123/appStoreVersions")
        #expect(path.path == "/v1/apps/123/appStoreVersions")
        #expect(path.segments == ["v1", "apps", "123", "appStoreVersions"])
        #expect(path.queryItems.isEmpty)
        #expect(path.url.absoluteString == "https://api.appstoreconnect.apple.com/v1/apps/123/appStoreVersions")
    }

    @Test("A full API URL is reduced to its path and query")
    func fullURL() throws {
        let path = try RequestPath("https://api.appstoreconnect.apple.com/v1/apps?cursor=AB.cd&limit=200")
        #expect(path.path == "/v1/apps")
        #expect(path.queryItems == [
            URLQueryItem(name: "cursor", value: "AB.cd"),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }

    @Test("Query parameters are decoded, then re-encoded strictly")
    func queryEncoding() throws {
        let path = try RequestPath("/v1/salesReports?filter[reportType]=SALES&filter%5Bversion%5D=1_0&x=a+b")
        #expect(path.queryItems == [
            URLQueryItem(name: "filter[reportType]", value: "SALES"),
            URLQueryItem(name: "filter[version]", value: "1_0"),
            URLQueryItem(name: "x", value: "a+b"),
        ])
        #expect(path.url.query == "filter%5BreportType%5D=SALES&filter%5Bversion%5D=1_0&x=a%2Bb")
    }

    @Test(
        "Paths that could hide the real resource are rejected",
        arguments: [
            "/v1/%61pps",
            "/v1/apps/../users/1",
            "/v1/./users",
            "/v1//users",
            "/v1/users/",
            "v1/users",
            "/users",
            "/v1",
            "/v1/apps#x",
            "/v1/app s",
            "/v1/apps\\..\\users",
            "",
        ]
    )
    func rejectsAmbiguousPaths(_ raw: String) {
        #expect(throws: ASCError.self) {
            try RequestPath(raw)
        }
    }

    @Test(
        "Only the App Store Connect API host is accepted",
        arguments: [
            "https://example.com/v1/apps",
            "http://api.appstoreconnect.apple.com/v1/apps",
            "https://api.appstoreconnect.apple.com.evil.com/v1/apps",
            "https://api.appstoreconnect.apple.com:8443/v1/apps",
            "https://user@api.appstoreconnect.apple.com/v1/apps",
        ]
    )
    func rejectsOtherHosts(_ raw: String) {
        #expect(throws: ASCError.self) {
            try RequestPath(raw)
        }
    }

    @Test("Malformed percent-encoding in the query is rejected")
    func rejectsMalformedQuery() {
        #expect(throws: ASCError.self) {
            try RequestPath("/v1/apps?filter=%ZZ")
        }
    }
}

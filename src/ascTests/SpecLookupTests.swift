//
//  SpecLookupTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import asc

@Suite("SpecLookup")
struct SpecLookupTests {
    static var document: [String: Any] {
        [
            "paths": [
                "/v1/builds/{id}": [
                    "get": ["operationId": "builds_getInstance"],
                    "patch": [
                        "operationId": "builds_updateInstance",
                        "requestBody": [
                            "content": [
                                "application/json": ["schema": ["$ref": "#/components/schemas/BuildUpdateRequest"]],
                            ],
                        ],
                        "responses": [
                            "200": [
                                "content": [
                                    "application/json": ["schema": ["$ref": "#/components/schemas/BuildResponse"]],
                                ],
                            ],
                        ],
                    ],
                ],
                "/v1/certificates/{id}": ["delete": ["operationId": "certificates_deleteInstance"]],
                "/v1/betaGroups": ["post": ["operationId": "betaGroups_createInstance"]],
            ],
            "components": [
                "schemas": [
                    "BuildUpdateRequest": [
                        "type": "object",
                        "properties": ["data": ["$ref": "#/components/schemas/Node"]],
                    ],
                    "Node": [
                        "type": "object",
                        "properties": ["child": ["$ref": "#/components/schemas/Node"]],
                    ],
                ],
            ],
        ]
    }

    let lookup = SpecLookup(document: Self.document)

    @Test("find matches all terms and shows the blocklist status")
    func find() {
        #expect(self.lookup.find(["builds"]) == [
            "GET /v1/builds/{id}",
            "PATCH /v1/builds/{id}  [BLOCKED attributes: expired]",
        ])
        #expect(self.lookup.find(["CERTIFICATES", "delete"]) == [
            "DELETE /v1/certificates/{id}  [BLOCKED: revokes or deactivates a certificate]",
        ])
        #expect(self.lookup.find(["betaGroups"]) == ["POST /v1/betaGroups"])
        #expect(self.lookup.find(["nothing"]).isEmpty)
    }

    @Test("show accepts concrete paths, resolves refs and stops at recursion")
    func show() throws {
        let output = try self.lookup.show(method: "patch", path: "/v1/builds/B123")
        let json = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])

        #expect(json["operation"] as? String == "PATCH /v1/builds/{id}")
        #expect(json["blocked"] as? String == "[BLOCKED attributes: expired]")
        #expect((json["responses"] as? [String: String]) == ["200": "BuildResponse"])

        let body = try #require(json["requestBody"] as? [String: Any])
        let data = try #require((body["properties"] as? [String: Any])?["data"] as? [String: Any])
        let child = try #require((data["properties"] as? [String: Any])?["child"] as? [String: String])
        #expect(child == ["$ref": "Node"])
    }

    @Test("show rejects unknown operations")
    func showUnknown() {
        #expect(throws: ASCError.self) {
            try self.lookup.show(method: "DELETE", path: "/v1/builds/1")
        }
    }
}

//
//  BlocklistTests.swift
//  ascTests
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation
import Testing
@testable import asc

@Suite("Blocklist")
struct BlocklistTests {
    struct Case: CustomTestStringConvertible {
        let method: String
        let path: String
        let body: String?

        init(_ method: String, _ path: String, _ body: String? = nil) {
            self.method = method
            self.path = path
            self.body = body
        }

        var testDescription: String {
            "\(self.method) \(self.path) \(self.body ?? "")"
        }
    }

    static func violation(_ testCase: Case) throws -> String? {
        try Blocklist.violation(
            method: testCase.method,
            path: RequestPath(testCase.path),
            body: testCase.body.map { Data($0.utf8) }
        )
    }

    static func attributes(_ type: String, _ attributes: String) -> String {
        #"{"data":{"type":"\#(type)","id":"1","attributes":{\#(attributes)}}}"#
    }

    /// Every prohibited operation from AGENTS.md, as real endpoints from spec 4.5.1.
    static let mustBlock: [Case] = [
        // Remove from sale / availability
        Case(
            "PATCH",
            "/v1/territoryAvailabilities/T1",
            Self.attributes("territoryAvailabilities", #""available":false"#)
        ),
        Case(
            "POST",
            "/v2/appAvailabilities",
            Self.attributes("appAvailabilities", #""availableInNewTerritories":false"#)
        ),
        Case("POST", "/v1/inAppPurchaseAvailabilities"),
        Case("POST", "/v1/subscriptionAvailabilities"),
        Case("PATCH", "/v1/subscriptionPlanAvailabilities/1/relationships/availableTerritories"),
        Case("POST", "/v1/endAppAvailabilityPreOrders"),
        Case("PATCH", "/v1/appStoreVersions/1", Self.attributes("appStoreVersions", #""downloadable":false"#)),
        Case(
            "PATCH",
            "/v1/subscriptions/1",
            Self.attributes("subscriptions", #""marketSettings":["APPLE_SCHOOL"]"#)
        ),
        // Certificates
        Case("DELETE", "/v1/certificates/C1"),
        Case("PATCH", "/v1/certificates/C1", Self.attributes("certificates", #""activated":false"#)),
        // Users
        Case("DELETE", "/v1/users/U1"),
        Case("PATCH", "/v1/users/U1", Self.attributes("users", #""roles":["ADMIN"]"#)),
        Case("POST", "/v1/users/U1/relationships/visibleApps"),
        Case("DELETE", "/v1/users/U1/relationships/visibleApps"),
        Case("POST", "/v1/userInvitations"),
        Case("DELETE", "/v1/userInvitations/I1"),
        // Builds
        Case("PATCH", "/v1/builds/B1", Self.attributes("builds", #""expired":true"#)),
        // Prices
        Case("POST", "/v1/appPriceSchedules"),
        Case("POST", "/v1/inAppPurchasePriceSchedules"),
        Case("POST", "/v1/subscriptionPrices"),
        Case("DELETE", "/v1/subscriptionPrices/1"),
        Case("DELETE", "/v1/subscriptions/1/relationships/prices"),
        // Submissions and releases
        Case("POST", "/v1/reviewSubmissions"),
        Case("PATCH", "/v1/reviewSubmissions/R1", Self.attributes("reviewSubmissions", #""submitted":true"#)),
        Case("POST", "/v1/reviewSubmissionItems"),
        Case("DELETE", "/v1/appStoreVersionSubmissions/1"),
        Case("POST", "/v1/appStoreVersionReleaseRequests"),
        Case("POST", "/v1/appStoreVersionPhasedReleases"),
        Case("PATCH", "/v1/appStoreVersionPhasedReleases/1"),
        Case("POST", "/v1/inAppPurchaseSubmissions"),
        Case("POST", "/v1/subscriptionSubmissions"),
        Case("POST", "/v1/subscriptionGroupSubmissions"),
        Case(
            "PATCH",
            "/v1/appStoreVersions/1",
            Self.attributes("appStoreVersions", #""releaseType":"AFTER_APPROVAL""#)
        ),
        Case(
            "PATCH",
            "/v1/appStoreVersions/1",
            Self.attributes("appStoreVersions", #""earliestReleaseDate":"2030-01-01""#)
        ),
        Case("PATCH", "/v1/nominations/1", Self.attributes("nominations", #""submitted":true"#)),
        // Irreversible
        Case("PATCH", "/v1/subscriptions/1", Self.attributes("subscriptions", #""familySharable":true"#)),
        Case("PATCH", "/v2/inAppPurchases/1", Self.attributes("inAppPurchases", #""familySharable":true"#)),
        // Alternative distribution
        Case("POST", "/v1/alternativeDistributionKeys"),
        Case("DELETE", "/v1/alternativeDistributionDomains/1"),
        Case("PATCH", "/v1/marketplaceWebhooks/1"),
        // Destructive deletes
        Case("DELETE", "/v1/appStoreVersions/1"),
        Case("DELETE", "/v2/inAppPurchases/1"),
        Case("DELETE", "/v1/subscriptions/1"),
        Case("DELETE", "/v1/subscriptionGroups/1"),
        Case("DELETE", "/v1/appCustomProductPages/1"),
        Case("DELETE", "/v1/appEvents/1"),
        Case("DELETE", "/v1/appStoreVersionExperiments/1"),
        Case("DELETE", "/v1/ciProducts/1"),
        Case("DELETE", "/v1/ciWorkflows/1"),
        Case("DELETE", "/v1/webhooks/1"),
        Case("DELETE", "/v1/endUserLicenseAgreements/1"),
        Case("DELETE", "/v1/appClipDefaultExperiences/1"),
        Case("DELETE", "/v2/gameCenterLeaderboards/1"),
        Case("DELETE", "/v1/gameCenterMatchmakingQueues/1"),
    ]

    static let mustAllow: [Case] = [
        Case("GET", "/v1/territoryAvailabilities/T1"),
        Case("GET", "/v1/users"),
        Case(
            "PATCH",
            "/v1/appStoreVersionLocalizations/1",
            Self.attributes("appStoreVersionLocalizations", #""whatsNew":"Fixes""#)
        ),
        Case("PATCH", "/v1/appStoreVersions/1", Self.attributes("appStoreVersions", #""versionString":"2.0""#)),
        Case("PATCH", "/v1/builds/1", Self.attributes("builds", #""usesNonExemptEncryption":false"#)),
        Case("PATCH", "/v1/apps/1", Self.attributes("apps", #""primaryLocale":"de-DE""#)),
        Case("POST", "/v1/customerReviewResponses"),
        Case("DELETE", "/v1/customerReviewResponses/1"),
        Case("POST", "/v1/analyticsReportRequests"),
        Case("DELETE", "/v1/analyticsReportRequests/1"),
        Case("POST", "/v1/betaGroups"),
        Case("DELETE", "/v1/betaGroups/1"),
        Case("DELETE", "/v1/appScreenshots/1"),
        Case("POST", "/v1/certificates"),
        Case("PATCH", "/v1/subscriptions/1", Self.attributes("subscriptions", #""name":"Pro""#)),
        Case(
            "PATCH",
            "/v2/appStoreVersionExperiments/1",
            Self.attributes("appStoreVersionExperiments", #""name":"B""#)
        ),
        Case("DELETE", "/v1/gameCenterLeaderboardLocalizations/1"),
        // Offers and offer codes
        Case("POST", "/v1/subscriptionIntroductoryOffers"),
        Case("DELETE", "/v1/subscriptions/1/relationships/introductoryOffers"),
        Case("POST", "/v1/subscriptionPromotionalOffers"),
        Case("POST", "/v1/subscriptionOfferCodes"),
        Case("POST", "/v1/subscriptionOfferCodeOneTimeUseCodes"),
        Case("POST", "/v1/inAppPurchaseOfferCodes"),
        Case("POST", "/v1/winBackOffers"),
        Case(
            "POST",
            "/v1/winBackOffers",
            #"{"data":{"type":"winBackOffers"},"included":[{"type":"winBackOfferPrices","id":"${p}"}]}"#
        ),
        // Creating and editing in-app purchases and subscriptions
        Case("POST", "/v2/inAppPurchases", Self.attributes("inAppPurchases", #""name":"Pro","productId":"pro""#)),
        Case("POST", "/v1/subscriptions", Self.attributes("subscriptions", #""name":"Monthly""#)),
        Case("POST", "/v1/subscriptionGroups"),
        // Identifiers and profiles
        Case("DELETE", "/v1/bundleIds/B1"),
        Case("POST", "/v1/bundleIdCapabilities"),
        Case("DELETE", "/v1/profiles/P1"),
        Case("PATCH", "/v1/apps/1", Self.attributes("apps", #""bundleId":"com.example.other""#)),
        // TestFlight review, A/B tests, Game Center releases
        Case("POST", "/v1/betaAppReviewSubmissions"),
        Case(
            "PATCH",
            "/v2/appStoreVersionExperiments/1",
            Self.attributes("appStoreVersionExperiments", #""started":true"#)
        ),
        Case("POST", "/v1/appStoreVersionPromotions"),
        Case("POST", "/v1/gameCenterLeaderboardReleases"),
        // Relationship edits on objects whose deletion is blocked
        Case("DELETE", "/v2/gameCenterLeaderboardSets/1/relationships/gameCenterLeaderboards"),
    ]

    @Test("Prohibited operations are blocked", arguments: Self.mustBlock)
    func blocksProhibitedOperation(_ testCase: Case) throws {
        #expect(try Self.violation(testCase) != nil)
    }

    @Test("Ordinary operations are allowed", arguments: Self.mustAllow)
    func allowsOrdinaryOperation(_ testCase: Case) throws {
        #expect(try Self.violation(testCase) == nil)
    }

    @Test("Every rule blocks a request built from its own pattern")
    func everyRuleBlocks() throws {
        for rule in Blocklist.rules {
            var segments = rule.pattern.split(separator: "/").map(String.init)
            if segments.last == "**" {
                segments.removeLast()
            }
            let path = "/" + segments.map { segment in
                switch segment {
                case "v*": "v1"
                case "*": "ID1"
                default: segment.replacingOccurrences(of: "*", with: "x")
                }
            }.joined(separator: "/")
            let body = rule.attributes.map { attributes in
                Self.attributes("x", attributes.map { #""\#($0)":true"# }.joined(separator: ","))
            }
            for method in rule.methods {
                let reason = try Self.violation(Case(method, path, body))
                #expect(reason != nil, "\(method) \(path) not blocked by \(rule.pattern)")
            }
        }
    }

    @Test("Path matching ignores case")
    func ignoresCase() throws {
        #expect(try Self.violation(Case("DELETE", "/v1/CERTIFICATES/C1")) != nil)
    }

    @Test("Attribute rules ignore case")
    func attributeRulesIgnoreCase() throws {
        #expect(try Self.violation(Case("PATCH", "/v1/builds/1", Self.attributes("builds", #""EXPIRED":true"#))) != nil)
    }

    @Test("Attribute rules apply to array data")
    func attributeRulesApplyToArrayData() throws {
        let body = #"{"data":[{"type":"builds","id":"1","attributes":{"expired":true}}]}"#
        #expect(try Self.violation(Case("PATCH", "/v1/builds/1", body)) != nil)
    }

    @Test("Prices can't be smuggled in as included resources")
    func blocksIncludedPrices() throws {
        let body = """
        {"data":{"type":"subscriptions","id":"1","attributes":{"name":"Pro"}},
         "included":[{"type":"subscriptionPrices","id":"${new}","attributes":{"startDate":null}}]}
        """
        #expect(try Self
            .violation(Case("PATCH", "/v1/subscriptions/1", body)) ==
            "the request body contains a 'subscriptionPrices' resource")
    }

    @Test("Blocked types are found at any depth and in any case")
    func blocksNestedTypes() throws {
        let body = #"{"data":{"type":"apps","id":"1","relationships":{"x":{"data":[{"type":"TerritoryAvailabilities","id":"2"}]}}}}"#
        #expect(try Self.violation(Case("PATCH", "/v1/apps/1", body)) != nil)
    }

    @Test("A body that isn't a JSON object is refused", arguments: ["not json", "[1,2]", "\"string\""])
    func refusesUncheckableBody(_ body: String) throws {
        #expect(try Self
            .violation(Case("POST", "/v1/betaGroups", body)) ==
            "the request body is not a JSON object and can't be checked")
    }

    @Test("GET is never blocked, whatever the path")
    func neverBlocksGET() throws {
        #expect(try Self.violation(Case("GET", "/v1/appPriceSchedules")) == nil)
    }

    @Test("Glob patterns match exactly one segment; ** matches the rest")
    func patternSemantics() {
        #expect(Blocklist.matches("/v*/users/**", ["v1", "users"]))
        #expect(Blocklist.matches("/v*/users/**", ["v1", "users", "U1", "relationships", "visibleApps"]))
        #expect(!Blocklist.matches("/v*/users/**", ["v1", "userInvitationsX"]))
        #expect(Blocklist.matches("/v*/builds/*", ["v1", "builds", "B1"]))
        #expect(!Blocklist.matches("/v*/builds/*", ["v1", "builds", "B1", "relationships", "app"]))
        #expect(!Blocklist.matches("/v*/builds/*", ["v1", "builds"]))
        #expect(Blocklist.matches("/v*/gameCenter*Releases/**", ["v1", "gameCenterLeaderboardSetReleases", "1"]))
        #expect(!Blocklist.matches("/v*/gameCenter*Releases/**", ["v1", "gameCenterLeaderboards", "1"]))
    }

    @Test("The canonical body keeps the content and drops formatting")
    func canonicalBody() throws {
        let body = Data(#"{ "data" : { "type":"builds", "id":"1" } }"#.utf8)
        #expect(try String(decoding: Blocklist.canonicalBody(body), as: UTF8.self) ==
            #"{"data":{"id":"1","type":"builds"}}"#)
    }
}

//
//  Blocklist.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// Write operations asc refuses to send. Checked before any credentials are loaded or a token is signed; there is
/// no override. Reviewed against API spec 4.5.1.
///
/// Patterns match path segments case-insensitively: `*` and other globs match within one segment, a trailing `**`
/// matches any number of further segments (including none).
enum Blocklist {
    struct Rule {
        let methods: Set<String>
        let pattern: String
        /// When set, the rule only applies if the request body sets one of these attributes.
        let attributes: Set<String>?
        let reason: String

        init(_ methods: Set<String>, _ pattern: String, attributes: Set<String>? = nil, _ reason: String) {
            self.methods = methods
            self.pattern = pattern
            self.attributes = attributes
            self.reason = reason
        }
    }

    static let writeMethods: Set<String> = ["POST", "PATCH", "DELETE"]

    private static let write = Self.writeMethods
    private static let delete: Set<String> = ["DELETE"]

    static let rules: [Rule] = [
        // Availability (includes removing an app from sale)
        Rule(write, "/v*/territoryAvailabilities/**", "changes territory availability"),
        Rule(write, "/v*/appAvailabilities/**", "changes app availability"),
        Rule(write, "/v*/inAppPurchaseAvailabilities/**", "changes in-app purchase availability"),
        Rule(write, "/v*/subscriptionAvailabilities/**", "changes subscription availability"),
        Rule(write, "/v*/subscriptionPlanAvailabilities/**", "changes subscription availability"),
        Rule(
            ["POST", "PATCH"],
            "/v*/subscriptions/**",
            attributes: ["marketSettings"],
            "changes subscription availability"
        ),
        Rule(write, "/v*/endAppAvailabilityPreOrders/**", "ends a pre-order"),
        Rule(["PATCH"], "/v*/appStoreVersions/*", attributes: ["downloadable"], "changes version availability"),

        // Prices
        Rule(write, "/v*/appPriceSchedules/**", "changes app prices"),
        Rule(write, "/v*/inAppPurchasePriceSchedules/**", "changes in-app purchase prices"),
        Rule(write, "/v*/subscriptionPrices/**", "changes subscription prices"),
        Rule(write, "/v*/subscriptions/*/relationships/prices", "changes subscription prices"),

        // Certificates
        Rule(["PATCH", "DELETE"], "/v*/certificates/**", "revokes or deactivates a certificate"),

        // Users
        Rule(write, "/v*/users/**", "changes users, roles or app access"),
        Rule(write, "/v*/userInvitations/**", "invites or uninvites users"),

        // Builds
        Rule(["PATCH"], "/v*/builds/*", attributes: ["expired"], "expires a build"),

        // Review submissions and releases
        Rule(write, "/v*/reviewSubmissions/**", "submits or cancels an App Review submission"),
        Rule(write, "/v*/reviewSubmissionItems/**", "changes an App Review submission"),
        Rule(write, "/v*/appStoreVersionSubmissions/**", "submits or cancels an App Review submission"),
        Rule(write, "/v*/appStoreVersionReleaseRequests/**", "releases a version"),
        Rule(write, "/v*/appStoreVersionPhasedReleases/**", "changes a phased release"),
        Rule(write, "/v*/inAppPurchaseSubmissions/**", "submits an in-app purchase for review"),
        Rule(write, "/v*/subscriptionSubmissions/**", "submits a subscription for review"),
        Rule(write, "/v*/subscriptionGroupSubmissions/**", "submits a subscription group for review"),
        Rule(
            ["PATCH"],
            "/v*/appStoreVersions/*",
            attributes: ["releaseType", "earliestReleaseDate"],
            "changes when a version is released"
        ),
        Rule(
            ["POST"],
            "/v*/appStoreVersions",
            attributes: ["releaseType", "earliestReleaseDate"],
            "changes when a version is released"
        ),
        Rule(["POST", "PATCH"], "/v*/nominations/**", attributes: ["submitted"], "submits a featuring nomination"),

        // Irreversible settings
        Rule(
            ["POST", "PATCH"],
            "/v*/subscriptions/**",
            attributes: ["familySharable"],
            "enables Family Sharing (irreversible)"
        ),
        Rule(
            ["POST", "PATCH"],
            "/v*/inAppPurchases/**",
            attributes: ["familySharable"],
            "enables Family Sharing (irreversible)"
        ),

        // Alternative distribution
        Rule(write, "/v*/marketplace*/**", "changes alternative marketplace settings"),
        Rule(write, "/v*/alternativeDistribution*/**", "changes alternative distribution"),

        // Destructive deletes of the objects themselves; their relationships stay editable
        Rule(delete, "/v*/appStoreVersions/*", "deletes an App Store version"),
        Rule(delete, "/v*/inAppPurchases/*", "deletes an in-app purchase"),
        Rule(delete, "/v*/subscriptions/*", "deletes a subscription"),
        Rule(delete, "/v*/subscriptionGroups/*", "deletes a subscription group"),
        Rule(delete, "/v*/appCustomProductPages/*", "deletes a custom product page"),
        Rule(delete, "/v*/appEvents/*", "deletes an in-app event"),
        Rule(delete, "/v*/appStoreVersionExperiments/*", "deletes an A/B test"),
        Rule(delete, "/v*/ciProducts/*", "deletes an Xcode Cloud product"),
        Rule(delete, "/v*/ciWorkflows/*", "deletes an Xcode Cloud workflow"),
        Rule(delete, "/v*/webhooks/*", "deletes a webhook"),
        Rule(delete, "/v*/endUserLicenseAgreements/*", "deletes a license agreement"),
        Rule(delete, "/v*/appClipDefaultExperiences/*", "deletes an App Clip experience"),
        Rule(delete, "/v*/gameCenterAchievements/*", "deletes Game Center achievements"),
        Rule(delete, "/v*/gameCenterLeaderboards/*", "deletes Game Center leaderboards"),
        Rule(delete, "/v*/gameCenterLeaderboardSets/*", "deletes Game Center leaderboard sets"),
        Rule(delete, "/v*/gameCenterGroups/*", "deletes a Game Center group"),
        Rule(delete, "/v*/gameCenterActivities/*", "deletes Game Center activities"),
        Rule(delete, "/v*/gameCenterChallenges/*", "deletes Game Center challenges"),
        Rule(delete, "/v*/gameCenterMatchmaking*/*", "deletes Game Center matchmaking configuration"),
    ]

    /// Resource types that may never appear in a write body, so prices or availability can't be smuggled in as
    /// `included` inline resources (for example a `PATCH /v1/subscriptions/{id}` with new prices).
    static let blockedTypes: Set<String> = [
        "appPrices",
        "appPriceSchedules",
        "inAppPurchasePrices",
        "inAppPurchasePriceSchedules",
        "subscriptionPrices",
        "territoryAvailabilities",
        "appAvailabilities",
    ]

    /// Returns why the request is blocked, or nil if it may be sent. The caller must send `canonicalBody(_:)`, not the
    /// raw body, so the server parses exactly what was checked here (duplicate JSON keys could otherwise differ).
    static func violation(method: String, path: RequestPath, body: Data?) -> String? {
        guard self.writeMethods.contains(method) else {
            return nil
        }

        var json: Any?
        if let body, !body.isEmpty {
            guard let object = try? JSONSerialization.jsonObject(with: body), object is [String: Any] else {
                return "the request body is not a JSON object and can't be checked"
            }
            json = object
        }

        let attributes = json.map(self.attributeNames) ?? []
        for rule in self.rules where rule.methods.contains(method) && self.matches(rule.pattern, path.segments) {
            if
                let ruleAttributes = rule.attributes,
                Set(ruleAttributes.map { $0.lowercased() }).isDisjoint(with: attributes)
            {
                continue
            }
            return rule.reason
        }

        if let json, let type = self.firstBlockedType(in: json) {
            return "the request body contains a '\(type)' resource"
        }
        return nil
    }

    static func canonicalBody(_ body: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: body)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func matches(_ pattern: String, _ segments: [Substring]) -> Bool {
        let patternSegments = pattern.split(separator: "/")
        let hasTail = patternSegments.last == "**"
        let fixed = hasTail ? patternSegments.dropLast() : patternSegments[...]

        guard hasTail ? segments.count >= fixed.count : segments.count == fixed.count else {
            return false
        }
        return zip(fixed, segments).allSatisfy { patternSegment, segment in
            fnmatch(String(patternSegment), String(segment), FNM_CASEFOLD) == 0
        }
    }

    /// Lowercased, matching the case-insensitive comparison in `violation`.
    private static func attributeNames(in json: Any) -> Set<String> {
        let data = (json as? [String: Any])?["data"]
        let resources = (data as? [[String: Any]]) ?? (data as? [String: Any]).map { [$0] } ?? []
        var names = Set<String>()
        for resource in resources {
            if let attributes = resource["attributes"] as? [String: Any] {
                names.formUnion(attributes.keys.map { $0.lowercased() })
            }
        }
        return names
    }

    private static func firstBlockedType(in json: Any) -> String? {
        if let dictionary = json as? [String: Any] {
            if
                let type = dictionary["type"] as? String,
                self.blockedTypes.contains(where: { $0.caseInsensitiveCompare(type) == .orderedSame })
            {
                return type
            }
            return dictionary.values.lazy.compactMap(self.firstBlockedType).first
        }
        if let array = json as? [Any] {
            return array.lazy.compactMap(self.firstBlockedType).first
        }
        return nil
    }
}

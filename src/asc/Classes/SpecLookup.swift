//
//  SpecLookup.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// Endpoint lookups in the cached spec, so agents don't have to read 7 MB of JSON.
struct SpecLookup {
    let document: [String: Any]

    private var paths: [String: [String: Any]] {
        (self.document["paths"] as? [String: [String: Any]]) ?? [:]
    }

    private var schemas: [String: Any] {
        ((self.document["components"] as? [String: Any])?["schemas"] as? [String: Any]) ?? [:]
    }

    // MARK: Public

    /// One line per operation whose path or operation ID contains every term, with its blocklist status.
    func find(_ terms: [String]) -> [String] {
        var lines = [String]()
        for path in self.paths.keys.sorted() {
            for method in HTTPMethod.allCases {
                guard let operation = self.paths[path]?[method.rawValue.lowercased()] as? [String: Any] else {
                    continue
                }
                let haystack = "\(path) \(operation["operationId"] as? String ?? "")".lowercased()
                guard terms.allSatisfy({ haystack.contains($0.lowercased()) }) else {
                    continue
                }
                lines.append("\(method.rawValue) \(path)\(self.blockStatus(method: method, path: path))")
            }
        }
        return lines
    }

    /// Parameters, resolved request body and response schema names of one operation. `path` may be the template
    /// (`/v1/apps/{id}`) or a concrete path (`/v1/apps/123`).
    func show(method argument: String, path: String) throws -> String {
        guard
            let method = HTTPMethod(argument: argument),
            let template = self.template(matching: path),
            let operation = self.paths[template]?[method.rawValue.lowercased()] as? [String: Any] else
        {
            throw ASCError.usage("no \(argument.uppercased()) \(path) in the spec; try `asc spec find <term>`")
        }

        var result: [String: Any] = ["operation": "\(method.rawValue) \(template)"]
        result["blocked"] = self.blockStatus(method: method, path: template).trimmingCharacters(in: .whitespaces)
        if let operationID = operation["operationId"] {
            result["operationId"] = operationID
        }
        let parameters = (self.paths[template]?["parameters"] as? [Any] ?? []) +
            (operation["parameters"] as? [Any] ?? [])
        if !parameters.isEmpty {
            result["parameters"] = parameters.map { self.resolve($0, depth: 0, seen: []) }
        }
        if
            let body = (operation["requestBody"] as? [String: Any])?["content"] as? [String: Any],
            let schema = (body["application/json"] as? [String: Any])?["schema"]
        {
            result["requestBody"] = self.resolve(schema, depth: 0, seen: [])
        }
        if let responses = operation["responses"] as? [String: Any] {
            result["responses"] = responses.mapValues(self.responseSchemaName)
        }

        let data = try JSONSerialization.data(
            withJSONObject: result,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: Private

    private func blockStatus(method: HTTPMethod, path: String) -> String {
        guard let requestPath = try? RequestPath(path.replacingOccurrences(of: "{id}", with: "ID")) else {
            return ""
        }
        if let reason = Blocklist.violation(method: method, path: requestPath, body: nil) {
            return "  [BLOCKED: \(reason)]"
        }
        let attributes = Blocklist.applicableRules(method: method, path: requestPath).flatMap { $0.attributes ?? [] }
        if !attributes.isEmpty {
            return "  [BLOCKED attributes: \(attributes.sorted().joined(separator: ", "))]"
        }
        return ""
    }

    private func template(matching path: String) -> String? {
        if self.paths[path] != nil {
            return path
        }
        let segments = path.split(separator: "/")
        return self.paths.keys.sorted().first { template in
            let templateSegments = template.split(separator: "/")
            return templateSegments.count == segments.count && zip(templateSegments, segments).allSatisfy {
                $0 == $1 || ($0.hasPrefix("{") && $0.hasSuffix("}"))
            }
        }
    }

    private func responseSchemaName(_ response: Any) -> String {
        guard
            let content = (response as? [String: Any])?["content"] as? [String: Any],
            let schema = content.values.compactMap({ ($0 as? [String: Any])?["schema"] as? [String: Any] }).first else
        {
            return (response as? [String: Any])?["description"] as? String ?? ""
        }
        if let ref = schema["$ref"] as? String {
            return String(ref.split(separator: "/").last ?? "")
        }
        return (schema["type"] as? String) ?? "inline schema"
    }

    /// Inlines `$ref`s up to a depth limit; recursive or deeper references stay as `$ref: Name`.
    private func resolve(_ node: Any, depth: Int, seen: Set<String>) -> Any {
        if let dictionary = node as? [String: Any] {
            if let ref = dictionary["$ref"] as? String {
                let name = String(ref.split(separator: "/").last ?? "")
                guard depth < 8, !seen.contains(name), let schema = self.schemas[name] else {
                    return ["$ref": name]
                }
                return self.resolve(schema, depth: depth + 1, seen: seen.union([name]))
            }
            return dictionary.mapValues { self.resolve($0, depth: depth, seen: seen) }
        }
        if let array = node as? [Any] {
            return array.map { self.resolve($0, depth: depth, seen: seen) }
        }
        return node
    }
}

//
//  APIClient.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

struct APIClient {
    static let maxRateLimitRetries = 5

    /// Ephemeral and without a URL cache: API responses (sales data, user lists) must never be written to disk.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()

    let credentials: Credentials

    /// Sends one request, retrying on 429. Gzip bodies (sales and finance reports) come back decompressed.
    func send(method: String, path: RequestPath, body: Data?) async throws -> Data {
        var request = URLRequest(url: path.url)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        var attempt = 0
        while true {
            try request.setValue("Bearer \(JWT.token(for: self.credentials))", forHTTPHeaderField: "Authorization")
            let (data, response) = try await Self.session.data(for: request)
            let http = response as! HTTPURLResponse

            if http.statusCode == 429, attempt < Self.maxRateLimitRetries {
                attempt += 1
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                try await Task.sleep(for: .seconds(retryAfter ?? pow(2, Double(attempt))))
                continue
            }
            guard (200..<300).contains(http.statusCode) else {
                throw ASCError.api(status: http.statusCode, body: data)
            }
            return try Self.gunzipIfNeeded(data)
        }
    }

    /// Follows `links.next` and merges every page's `data` and `included` into one document.
    func sendPaginated(path: RequestPath) async throws -> Data {
        var data = [Any]()
        var included = [Any]()
        var includedKeys = Set<String>()
        var next: RequestPath? = path

        while let current = next {
            let page = try await self.send(method: "GET", path: current, body: nil)
            guard let document = try JSONSerialization.jsonObject(with: page) as? [String: Any] else {
                throw ASCError.failure("expected a JSON object from \(current.path)")
            }
            guard let pageData = document["data"] as? [Any] else {
                // Not a collection; nothing to paginate.
                return page
            }
            data += pageData
            for case let resource as [String: Any] in document["included"] as? [Any] ?? [] {
                let key = "\(resource["type"] ?? "")/\(resource["id"] ?? "")"
                if includedKeys.insert(key).inserted {
                    included.append(resource)
                }
            }
            next = try ((document["links"] as? [String: Any])?["next"] as? String).map(RequestPath.init)
        }

        var merged: [String: Any] = ["data": data]
        if !included.isEmpty {
            merged["included"] = included
        }
        return try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .withoutEscapingSlashes])
    }

    static func gunzipIfNeeded(_ data: Data) throws -> Data {
        guard data.starts(with: [0x1F, 0x8B]) else {
            return data
        }
        let result = try ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/gunzip"),
            arguments: ["-c"],
            input: data,
            timeout: 120
        )
        guard result.status == 0, !result.isTimedOut else {
            throw ASCError.failure("gunzip failed: \(String(decoding: result.stderr, as: UTF8.self))")
        }
        return result.stdout
    }
}

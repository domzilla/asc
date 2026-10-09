//
//  Server.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation

struct Server {
    let credentials: Credentials
    let reference: String
    let expiresAt: Date

    // MARK: Public

    func handle(_ connection: Int32) async {
        defer { close(connection) }
        let response: Agent.Response
        var isStopping = false
        do {
            let request = try JSONDecoder().decode(Agent.Request.self, from: UnixSocket.readAll(connection))
            switch request.command {
            case .status:
                response = Agent.Response(exitCode: 0, message: self.status)
            case .stop:
                isStopping = true
                response = Agent.Response(exitCode: 0, message: "agent stopped")
            case .request:
                response = await self.perform(request)
            }
        } catch {
            response = Agent.Response(error: ASCError.agent("invalid request: \(error)"))
        }

        try? UnixSocket.writeAll(connection, JSONEncoder().encode(response))
        if isStopping {
            Agent.shutDown()
        }
    }

    // MARK: Private

    private var status: String {
        let minutes = Int(self.expiresAt.timeIntervalSinceNow / 60)
        return """
        agent running (pid \(getpid()))
        credentials:   \(self.reference)
        key_id:        \(self.credentials.keyID.rawValue)
        issuer_id:     \(self.credentials.issuerID.rawValue)
        vendor_number: \(self.credentials.vendorNumber ?? "<missing>")
        expires:       \(ISO8601DateFormatter().string(from: self.expiresAt)) (in \(minutes) min)
        """
    }

    private func perform(_ request: Agent.Request) async -> Agent.Response {
        do {
            guard let method = request.method else {
                throw ASCError.usage("missing method")
            }
            guard let rawPath = request.path else {
                throw ASCError.usage("missing path")
            }
            if request.isPaginated, method != .get {
                throw ASCError.usage("--paginate only works with GET")
            }
            if request.body != nil, method == .get {
                throw ASCError.usage("GET requests take no --body")
            }

            let path = try RequestPath(rawPath)
            var body = request.body
            if method.isWrite {
                if let reason = Blocklist.violation(method: method, path: path, body: body) {
                    throw ASCError.blocked(reason)
                }
                body = try body.map(Blocklist.canonicalBody)
                try await Spec.shared.ensureWritesAllowed()
            }

            let client = APIClient(credentials: self.credentials)
            let data = request.isPaginated
                ? try await client.sendPaginated(path: path)
                : try await client.send(method: method, path: path, body: body)
            return Agent.Response(exitCode: 0, body: data)
        } catch {
            return Agent.Response(error: error)
        }
    }
}

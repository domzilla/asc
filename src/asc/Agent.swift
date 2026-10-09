//
//  Agent.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation

/// A short-lived background process that holds the API key in memory, so a session needs one 1Password approval
/// instead of one per call. It is the only process that ever has the key, and it runs the blocklist and spec gate
/// before signing anything.
enum Agent {
    static let defaultTTL: TimeInterval = 30 * 60

    struct Request: Codable {
        enum Command: String, Codable {
            case request
            case status
            case stop
        }

        var command: Command
        var method: HTTPMethod?
        var path: String?
        var body: Data?
        var isPaginated = false
    }

    struct Response: Codable {
        var exitCode: Int32
        var message: String?
        var body: Data?
    }

    /// Handed to the background process through its stdin, never through arguments or the environment.
    private struct Startup: Codable {
        let credentials: Credentials
        let reference: String
        let expiresAt: Date
    }

    static var socketPath: String {
        Spec.shared.cacheDirectory.appendingPathComponent("agent.sock").path
    }

    // MARK: Public

    /// Loads the key (one 1Password approval), starts the background process and returns its status.
    static func start(reference: String, ttl: TimeInterval) throws -> String {
        if let status = try? self.send(Request(command: .status)) {
            throw ASCError.agent("already running; stop it first\n\(status.message ?? "")")
        }

        let credentials = try Credentials.load(from: reference)
        _ = try JWT.token(for: credentials)

        try Spec.shared.createCacheDirectory()
        unlink(self.socketPath)

        let startup = try JSONEncoder().encode(
            Startup(credentials: credentials, reference: reference, expiresAt: Date().addingTimeInterval(ttl))
        )
        let pid = try self.spawnServer(input: startup)

        for _ in 0..<100 {
            if let response = try? self.send(Request(command: .status)) {
                return response.message ?? ""
            }
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == pid {
                throw ASCError.agent("the agent exited during startup")
            }
            usleep(100_000)
        }
        kill(pid, SIGTERM)
        throw ASCError.agent("the agent didn't start within 10 seconds")
    }

    static func send(_ request: Request) throws -> Response {
        let fd = try UnixSocket.connect(to: self.socketPath)
        defer { close(fd) }
        try UnixSocket.writeAll(fd, JSONEncoder().encode(request))
        shutdown(fd, SHUT_WR)
        let data = try UnixSocket.readAll(fd)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ASCError.agent("invalid response from the agent")
        }
    }

    /// Entry point of the background process (`asc agent serve`).
    static func serve() async throws {
        let startup = try JSONDecoder().decode(Startup.self, from: FileHandle.standardInput.readDataToEndOfFile())
        signal(SIGHUP, SIG_IGN)
        signal(SIGPIPE, SIG_IGN)

        let listener = try UnixSocket.listen(at: self.socketPath)
        let server = Server(
            credentials: startup.credentials,
            reference: startup.reference,
            expiresAt: startup.expiresAt
        )

        let acceptThread = Thread {
            while true {
                let connection = accept(listener, nil, nil)
                guard connection >= 0 else {
                    continue
                }
                guard UnixSocket.isSameUser(connection) else {
                    close(connection)
                    continue
                }
                Task.detached {
                    await server.handle(connection)
                }
            }
        }
        acceptThread.start()

        try? await Task.sleep(for: .seconds(max(0, startup.expiresAt.timeIntervalSinceNow)))
        self.shutDown()
    }

    static func parseTTL(_ string: String) throws -> TimeInterval {
        let units: [Character: TimeInterval] = ["s": 1, "m": 60, "h": 3600]
        guard
            let unit = string.last.flatMap({ units[$0] }),
            let value = Int(string.dropLast()),
            value > 0 else
        {
            throw ASCError.usage("--ttl expects a duration like 90s, 30m or 2h, got '\(string)'")
        }
        return TimeInterval(value) * unit
    }

    // MARK: Private

    fileprivate static func shutDown() -> Never {
        unlink(self.socketPath)
        exit(0)
    }

    /// Spawns `asc agent serve` in its own session, so it outlives the shell that started it.
    private static func spawnServer(input: Data) throws -> pid_t {
        guard let executable = Bundle.main.executablePath else {
            throw ASCError.agent("can't locate the asc executable")
        }
        var pipeFDs: [Int32] = [0, 0]
        guard pipe(&pipeFDs) == 0 else {
            throw ASCError.agent("can't create a pipe")
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        posix_spawn_file_actions_adddup2(&fileActions, pipeFDs[0], 0)
        posix_spawn_file_actions_addopen(&fileActions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&fileActions, 2, "/dev/null", O_WRONLY, 0)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))

        let strings: [String] = [executable, "agent", "serve"]
        let arguments: [UnsafeMutablePointer<CChar>?] = strings.map { $0.withCString { strdup($0) } } + [nil]
        defer { arguments.forEach { free($0) } }

        var pid: pid_t = 0
        let result = posix_spawn(&pid, executable, &fileActions, &attributes, arguments, environ)
        close(pipeFDs[0])
        guard result == 0 else {
            close(pipeFDs[1])
            throw ASCError.agent("can't start the agent: \(String(cString: strerror(result)))")
        }

        let writer = FileHandle(fileDescriptor: pipeFDs[1], closeOnDealloc: true)
        try writer.write(contentsOf: input)
        try writer.close()
        return pid
    }
}

private struct Server {
    let credentials: Credentials
    let reference: String
    let expiresAt: Date

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

    private var status: String {
        let minutes = Int(self.expiresAt.timeIntervalSinceNow / 60)
        return """
        agent running (pid \(getpid()))
        credentials:   \(self.reference)
        key_id:        \(self.credentials.keyID)
        issuer_id:     \(self.credentials.issuerID)
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

extension Agent.Response {
    init(error: any Error) {
        let error = ASCError(error)
        self.init(exitCode: error.exitCode, message: error.description)
    }
}

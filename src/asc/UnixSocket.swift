//
//  UnixSocket.swift
//  asc
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation

/// Minimal blocking Unix domain socket helpers. One request per connection: the client writes its message and shuts
/// down its write side, the server answers and closes.
enum UnixSocket {
    static let maxMessageSize = 256 * 1024 * 1024

    static func listen(at path: String) throws -> Int32 {
        let fd = try self.socket()
        var address = try self.address(path)
        // Created with 0600 regardless of the caller's umask.
        let previousMask = umask(0o177)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        umask(previousMask)
        guard bound == 0, Darwin.listen(fd, 16) == 0 else {
            let message = String(cString: strerror(errno))
            close(fd)
            throw ASCError.agent("can't listen on \(path): \(message)")
        }
        return fd
    }

    static func connect(to path: String) throws -> Int32 {
        let fd = try self.socket()
        var address = try self.address(path)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            close(fd)
            throw ASCError.agent("no agent running")
        }
        return fd
    }

    /// True if the peer runs as the same user as this process.
    static func isSameUser(_ fd: Int32) -> Bool {
        var uid: uid_t = 0
        var gid: gid_t = 0
        return getpeereid(fd, &uid, &gid) == 0 && uid == getuid()
    }

    static func readAll(_ fd: Int32) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0, errno == EINTR {
                continue
            }
            guard count >= 0 else {
                throw ASCError.agent("read failed: \(String(cString: strerror(errno)))")
            }
            if count == 0 {
                return data
            }
            data.append(contentsOf: buffer[0..<count])
            guard data.count <= self.maxMessageSize else {
                throw ASCError.agent("message too large")
            }
        }
    }

    static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            var offset = 0
            while offset < bytes.count {
                let count = write(fd, bytes.baseAddress! + offset, bytes.count - offset)
                if count < 0, errno == EINTR {
                    continue
                }
                guard count > 0 else {
                    throw ASCError.agent("write failed: \(String(cString: strerror(errno)))")
                }
                offset += count
            }
        }
    }

    // MARK: Private

    private static func socket() throws -> Int32 {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw ASCError.agent("can't create socket: \(String(cString: strerror(errno)))")
        }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        return fd
    }

    private static func address(_ path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw ASCError.agent("socket path too long: \(path)")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
        }
        return address
    }
}

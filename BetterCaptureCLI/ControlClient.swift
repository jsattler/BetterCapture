//
//  ControlClient.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import Darwin
import Foundation

/// Sends commands to the BetterCapture app over its control socket.
///
/// The tool ships inside the app at `BetterCapture.app/Contents/Helpers/bettercapture`, so it
/// talks to the app it came with, even when started through a link on the `PATH`.
struct ControlClient {

    static let releaseBundleIdentifier = "com.sattlerjoshua.BetterCapture"

    /// The app bundle this tool is inside of, if any
    let appURL: URL?
    let bundleIdentifier: String

    static func current() -> ControlClient {
        let executable = (Bundle.main.executableURL ?? URL(filePath: CommandLine.arguments[0])).resolvingSymlinksInPath()
        let appURL = executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        if appURL.pathExtension == "app", let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier {
            return ControlClient(appURL: appURL, bundleIdentifier: bundleIdentifier)
        }
        return ControlClient(appURL: nil, bundleIdentifier: releaseBundleIdentifier)
    }

    var appVersion: String {
        appURL.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleShortVersionString"] as? String } ?? "development"
    }

    private var socketPath: String {
        ControlProtocol.socketPath(bundleIdentifier: bundleIdentifier)
    }

    /// Sends a command and returns the app's result
    /// - Parameter launchIfNeeded: Whether to launch the app when it isn't running
    func send(_ command: ControlCommand, launchIfNeeded: Bool = true) throws(CLIError) -> ControlResult {
        let socket = try connect(launchIfNeeded: launchIfNeeded)
        defer { close(socket) }

        guard let request = try? JSONEncoder().encode(ControlRequest(command: command)) else {
            throw CLIError.invalidResponse
        }
        try write(request + [0x0A], to: socket)

        guard let response = try? JSONDecoder().decode(ControlResponse.self, from: readLine(from: socket)) else {
            throw CLIError.invalidResponse
        }
        if let error = response.error {
            throw CLIError(error)
        }
        guard let result = response.result else {
            throw CLIError.invalidResponse
        }
        return result
    }

    // MARK: - Connection

    private func connect(launchIfNeeded: Bool) throws(CLIError) -> Int32 {
        if let socket = openSocket() {
            return socket
        }

        guard launchIfNeeded else {
            throw .unreachable("BetterCapture isn't running.")
        }
        launchApp()

        let deadline = ContinuousClock.now + .seconds(15)
        while ContinuousClock.now < deadline {
            Thread.sleep(forTimeInterval: 0.2)
            if let socket = openSocket() {
                return socket
            }
        }

        throw .unreachable("Could not reach BetterCapture. Make sure it is installed and opens without errors.")
    }

    private func openSocket() -> Int32? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let path = Array(socketPath.utf8CString)
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            path.withUnsafeBytes { buffer.copyMemory(from: $0) }
        }

        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return nil }

        // Report a closed connection as an error instead of terminating the process
        var noSigPipe: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            close(socket)
            return nil
        }
        return socket
    }

    private func launchApp() {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/open")
        // -g keeps the app in the background, so launching it doesn't steal focus
        process.arguments = if let appURL {
            ["-g", appURL.path(percentEncoded: false)]
        } else {
            ["-g", "-b", bundleIdentifier]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private func write(_ data: Data, to socket: Int32) throws(CLIError) {
        var offset = 0
        while offset < data.count {
            let written = data[offset...].withUnsafeBytes { Darwin.write(socket, $0.baseAddress, $0.count) }
            guard written > 0 else {
                throw .unreachable("The connection to BetterCapture was closed.")
            }
            offset += written
        }
    }

    private func readLine(from socket: Int32) throws(CLIError) -> Data {
        var line = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)

        while true {
            let count = Darwin.read(socket, &buffer, buffer.count)
            if count < 0 && errno == EINTR {
                continue
            }
            guard count > 0 else { break }

            line.append(contentsOf: buffer[..<count])
            if let newline = line.firstIndex(of: 0x0A) {
                return line[..<newline]
            }
        }

        guard !line.isEmpty else {
            throw .unreachable("BetterCapture closed the connection without answering.")
        }
        return line
    }
}

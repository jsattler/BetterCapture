//
//  ControlServer.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation
import Network
import OSLog

/// Listens on a Unix domain socket for commands from the `bettercapture` command-line tool.
///
/// The socket accepts connections only from the current user: it lives in the per-user
/// temporary directory and is made readable and writable by its owner alone. Whether
/// commands are carried out is decided by ``ControlCommandHandler``.
final class ControlServer {

    private let socketPath: String
    private let handler: ControlCommandHandler
    private var listener: NWListener?

    /// Network framework delivers its callbacks on a dispatch queue, there is no alternative
    private let queue = DispatchQueue(label: "com.bettercapture.controlServer")

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "ControlServer")

    init(socketPath: String, handler: ControlCommandHandler) {
        self.socketPath = socketPath
        self.handler = handler
    }

    func start() {
        // Another copy of the app, such as a development build or the unit test host, must not
        // take the socket away from the one already serving it
        guard !Self.isAcceptingConnections(socketPath) else {
            logger.warning("Another BetterCapture instance is serving the control socket")
            return
        }

        // A socket file left behind by a previous run would make binding fail
        unlink(socketPath)

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .unix(path: socketPath)

        do {
            let listener = try NWListener(using: parameters)

            listener.stateUpdateHandler = { [socketPath, logger] state in
                switch state {
                case .ready:
                    chmod(socketPath, 0o600)
                    logger.info("Control server listening")
                case .failed(let error):
                    logger.error("Control server failed: \(error.localizedDescription)")
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.serve(connection)
                }
            }

            listener.start(queue: queue)
            self.listener = listener
        } catch {
            logger.error("Could not start control server: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        unlink(socketPath)
    }

    /// Whether a process is listening on the socket, as opposed to a file left behind
    private static func isAcceptingConnections(_ path: String) -> Bool {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(path.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return false }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            pathBytes.withUnsafeBytes { buffer.copyMemory(from: $0) }
        }

        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        defer { close(socket) }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        return result == 0
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)

        Task {
            let response: ControlResponse

            do {
                let line = try await connection.receiveLine()
                let request = try JSONDecoder().decode(ControlRequest.self, from: line)
                response = await handler.handle(request)
            } catch {
                response = .failure(ControlError(code: .invalidRequest, message: "Could not read the request: \(error.localizedDescription)"))
            }

            if let data = try? JSONEncoder().encode(response) {
                await connection.sendLine(data)
            }

            connection.cancel()
        }
    }
}

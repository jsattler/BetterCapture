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

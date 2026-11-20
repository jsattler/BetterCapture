//
//  NWConnection+Lines.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation
import Network

/// Line-based reading and writing, for the one-JSON-object-per-line control protocol
nonisolated extension NWConnection {

    /// Reads until the first newline, or until the peer closes the connection.
    /// - Parameter limit: The largest line accepted, so a misbehaving peer can't grow the buffer forever
    func receiveLine(limit: Int = 1 << 20) async throws -> Data {
        var buffer = Data()

        while true {
            let (chunk, isComplete) = try await receiveChunk()

            if let chunk {
                buffer.append(chunk)
            }

            if let newline = buffer.firstIndex(of: 0x0A) {
                return buffer[..<newline]
            }

            if isComplete || buffer.count > limit {
                return buffer
            }
        }
    }

    /// Writes the data followed by a newline
    func sendLine(_ data: Data) async {
        await withCheckedContinuation { continuation in
            send(content: data + [0x0A], completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
    }

    private func receiveChunk() async throws -> (Data?, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data, isComplete))
                }
            }
        }
    }
}

//
//  RecordingSessionStore.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation

/// The recordings started from the command line while the app runs, so they can be told apart
/// and looked up by ID or name after they have ended.
@MainActor
final class RecordingSessionStore {

    /// Ended recordings beyond this many are forgotten, oldest first
    static let historyLimit = 50

    /// Oldest first
    private(set) var sessions: [RecordingSession] = []

    var activeSessions: [RecordingSession] {
        sessions.filter(\.isActive)
    }

    func add(_ session: RecordingSession) {
        sessions.append(session)

        let ended = sessions.filter(\.hasEnded)
        if ended.count > Self.historyLimit {
            let forgotten = Set(ended.prefix(ended.count - Self.historyLimit).map(\.id))
            sessions.removeAll { forgotten.contains($0.id) }
        }
    }

    /// A short ID not used by any known recording
    func makeID() -> String {
        while true {
            let id = String(UUID().uuidString.lowercased().prefix(8))
            if !sessions.contains(where: { $0.id == id }) {
                return id
            }
        }
    }

    /// The recording a command acts on
    /// - Parameter selector: An ID or name. Without one, the only active recording.
    func session(matching selector: RecordingSelector?) throws(ControlError) -> RecordingSession {
        try Self.select(selector, in: sessions, id: \.id, name: \.name, isActive: \.isActive)
    }

    /// Picks the item a selector refers to.
    ///
    /// A selector matches a recording by ID first and then by name, preferring active
    /// recordings over ended ones. Without a selector, the only active recording is picked.
    nonisolated static func select<Item>(
        _ selector: RecordingSelector?,
        in items: [Item],
        id: (Item) -> String,
        name: (Item) -> String?,
        isActive: (Item) -> Bool
    ) throws(ControlError) -> Item {
        if let selector {
            func resolve(in items: [Item]) throws(ControlError) -> Item {
                let candidates = items.map {
                    TargetResolver.Candidate(item: $0, id: id($0), name: name($0) ?? "")
                }
                return try TargetResolver.resolve(selector, in: candidates, kind: "recording")
            }

            // Active recordings win, so a name can be reused once its recording has ended
            do {
                return try resolve(in: items.filter(isActive))
            } catch where error.code == .notFound {
                return try resolve(in: items)
            }
        }

        let active = items.filter(isActive)
        switch active.count {
        case 1:
            return active[0]
        case 0:
            throw ControlError(code: .notRecording, message: "No recording is in progress.")
        default:
            throw ControlError(
                code: .ambiguous,
                message: "\(active.count) recordings are in progress. Pass the ID or name of one.",
                candidates: active.map { "\(id($0))\t\(name($0) ?? "")" }
            )
        }
    }
}

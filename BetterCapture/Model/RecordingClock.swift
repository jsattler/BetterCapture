//
//  RecordingClock.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 19.11.26.
//

import Foundation

/// Measures the elapsed time of a recording, excluding time spent paused.
struct RecordingClock {
    private let startedAt: Date
    private var pausedAt: Date?
    private var pausedDuration: TimeInterval = 0

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }

    mutating func pause(at date: Date = .now) {
        guard pausedAt == nil else { return }
        pausedAt = date
    }

    mutating func resume(at date: Date = .now) {
        guard let pausedAt else { return }
        pausedDuration += date.timeIntervalSince(pausedAt)
        self.pausedAt = nil
    }

    /// Recorded time up to `date`. While paused, this stays at the time of the pause.
    func elapsed(at date: Date = .now) -> TimeInterval {
        (pausedAt ?? date).timeIntervalSince(startedAt) - pausedDuration
    }
}

//
//  RecordingInfo+Text.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation

extension RecordingInfo {

    /// A one-line description, such as `3f9c1a2e (demo) Recording 01:05 → /Users/…/Movies/BetterCapture/….mov`
    var text: String {
        let label = name.map { "\(id) (\($0))" } ?? id
        return "\(label) \(state.rawValue.capitalized) \(formattedDuration) → \(outputPath)"
    }

    var formattedDuration: String {
        let seconds = Int(durationSeconds)
        return Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }

    static func table(_ recordings: [RecordingInfo]) -> String {
        guard !recordings.isEmpty else { return "No recordings" }

        return TextTable.render(
            header: ["ID", "NAME", "STATE", "DURATION", "TARGET", "OUTPUT"],
            rows: recordings.map {
                [$0.id, $0.name ?? "", $0.state.rawValue, $0.formattedDuration, $0.target, $0.error ?? $0.outputPath]
            }
        )
    }
}

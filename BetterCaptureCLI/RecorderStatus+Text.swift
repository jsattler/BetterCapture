//
//  RecorderStatus+Text.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation

extension RecorderStatus {
    /// A one-line description, such as `Recording 01:05 → /Users/…/Movies/BetterCapture/….mov`
    var text: String {
        guard state != "idle" else { return "Idle" }

        let seconds = Int(durationSeconds)
        let duration = Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
        let path = outputPath.map { " → \($0)" } ?? ""
        return "\(state.capitalized) \(duration)\(path)"
    }
}

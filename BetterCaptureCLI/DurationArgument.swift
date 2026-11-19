//
//  DurationArgument.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

/// A duration such as `90`, `30s`, `2m`, `1.5h`. Plain numbers are seconds.
struct DurationArgument: ExpressibleByArgument {
    var seconds: Double

    init?(argument: String) {
        let multipliers: [Character: Double] = ["s": 1, "m": 60, "h": 3600]
        var number = Substring(argument)
        var multiplier = 1.0

        if let unit = number.last, let value = multipliers[unit] {
            multiplier = value
            number = number.dropLast()
        }

        guard let value = Double(number), value > 0 else { return nil }
        seconds = value * multiplier
    }
}

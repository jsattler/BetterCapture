//
//  AreaArgument.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

/// An area given as `x,y,width,height` in points
struct AreaArgument: ExpressibleByArgument {
    var rect: AreaRect

    init?(argument: String) {
        let values = argument.split(separator: ",").compactMap { Double($0.filter { !$0.isWhitespace }) }
        guard values.count == 4 else { return nil }
        rect = AreaRect(left: values[0], top: values[1], width: values[2], height: values[3])
    }
}

//
//  RecordingArgument.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

/// The recording a command acts on
struct RecordingArgument: ParsableArguments {

    @Argument(help: "ID or name of the recording. May be left out while only one recording is in progress.")
    var recording: String?
}

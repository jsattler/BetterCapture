//
//  SkillCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser

struct SkillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill",
        abstract: "Set up AI agents to use BetterCapture.",
        subcommands: [SkillShowCommand.self],
        defaultSubcommand: SkillShowCommand.self
    )
}

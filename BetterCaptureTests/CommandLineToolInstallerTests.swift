//
//  CommandLineToolInstallerTests.swift
//  BetterCaptureTests
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation
import Testing
@testable import BetterCapture

struct CommandLineToolInstallerTests {

    private let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
    private let fileManager = FileManager.default

    private var linkURL: URL { root.appending(path: "home/.local/bin/bettercapture") }

    /// Creates an executable at the path the tool has inside an app bundle
    private func makeTool(inApp name: String) throws -> URL {
        let url = root.appending(path: "\(name).app/Contents/Helpers/bettercapture")
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        fileManager.createFile(atPath: url.path(percentEncoded: false), contents: Data(), attributes: [.posixPermissions: 0o755])
        return url
    }

    private func destination() throws -> String {
        try fileManager.destinationOfSymbolicLink(atPath: linkURL.path(percentEncoded: false))
    }

    @Test func createsLinkAndDirectory() throws {
        let tool = try makeTool(inApp: "BetterCapture")

        #expect(CommandLineToolInstaller.installLink(at: linkURL, to: tool))
        #expect(try destination() == tool.path(percentEncoded: false))
    }

    @Test func repairsLinkToMovedApp() throws {
        let oldTool = try makeTool(inApp: "Old/BetterCapture")
        let newTool = try makeTool(inApp: "BetterCapture")
        CommandLineToolInstaller.installLink(at: linkURL, to: oldTool)
        try fileManager.removeItem(at: root.appending(path: "Old"))

        #expect(CommandLineToolInstaller.installLink(at: linkURL, to: newTool))
        #expect(try destination() == newTool.path(percentEncoded: false))
    }

    @Test func keepsSomeoneElsesLink() throws {
        let tool = try makeTool(inApp: "BetterCapture")
        try fileManager.createDirectory(at: linkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(atPath: linkURL.path(percentEncoded: false), withDestinationPath: "/usr/local/bin/other")

        #expect(!CommandLineToolInstaller.installLink(at: linkURL, to: tool))
        #expect(try destination() == "/usr/local/bin/other")
    }

    @Test func keepsRegularFile() throws {
        let tool = try makeTool(inApp: "BetterCapture")
        try fileManager.createDirectory(at: linkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        fileManager.createFile(atPath: linkURL.path(percentEncoded: false), contents: Data("#!/bin/sh".utf8))

        #expect(!CommandLineToolInstaller.installLink(at: linkURL, to: tool))
        #expect(fileManager.contents(atPath: linkURL.path(percentEncoded: false)) == Data("#!/bin/sh".utf8))
    }

    @Test func skipsMissingTool() {
        let missing = root.appending(path: "BetterCapture.app/Contents/Helpers/bettercapture")

        #expect(!CommandLineToolInstaller.installLink(at: linkURL, to: missing))
        #expect(!fileManager.fileExists(atPath: linkURL.path(percentEncoded: false)))
    }

    @Test func statusComparesResolvedPaths() throws {
        let tool = try makeTool(inApp: "BetterCapture")
        let other = try makeTool(inApp: "Other")
        CommandLineToolInstaller.installLink(at: linkURL, to: tool)
        let linkPath = linkURL.path(percentEncoded: false)

        #expect(CommandLineToolService.status(foundPath: linkPath, toolURL: tool) == .available)
        #expect(CommandLineToolService.status(foundPath: other.path(percentEncoded: false), toolURL: tool) != .available)
        #expect(CommandLineToolService.status(foundPath: nil, toolURL: tool) == .notOnPath)
    }
}

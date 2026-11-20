//
//  CommandLineToolInstaller.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation

/// Links `~/.local/bin/bettercapture` to the command-line tool inside the app.
///
/// `~/.local/bin` is user-writable, so no password is needed. The link is checked on every
/// launch, which also repairs it after the app has been moved. Anything at that path that
/// isn't a link to a BetterCapture tool belongs to someone else and is never replaced.
enum CommandLineToolInstaller {

    /// The tool shipped inside this app
    static var toolURL: URL {
        Bundle.main.bundleURL.appending(path: "Contents/Helpers/bettercapture")
    }

    static var linkURL: URL {
        URL.homeDirectory.appending(path: ".local/bin/bettercapture")
    }

    /// Creates or repairs the link
    /// - Returns: Whether the link now points at the tool
    @discardableResult
    static func installLink(
        at linkURL: URL = linkURL,
        to toolURL: URL = toolURL,
        fileManager: FileManager = .default
    ) -> Bool {
        let linkPath = linkURL.path(percentEncoded: false)
        let toolPath = toolURL.path(percentEncoded: false)

        guard fileManager.isExecutableFile(atPath: toolPath) else { return false }

        if let destination = try? fileManager.destinationOfSymbolicLink(atPath: linkPath) {
            if destination == toolPath {
                return true
            }
            guard isBetterCaptureTool(destination) else { return false }
            try? fileManager.removeItem(atPath: linkPath)
        } else if fileManager.fileExists(atPath: linkPath) {
            return false
        }

        do {
            try fileManager.createDirectory(at: linkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.createSymbolicLink(atPath: linkPath, withDestinationPath: toolPath)
            return true
        } catch {
            return false
        }
    }

    private static func isBetterCaptureTool(_ path: String) -> Bool {
        path.hasSuffix(".app/Contents/Helpers/bettercapture")
    }
}

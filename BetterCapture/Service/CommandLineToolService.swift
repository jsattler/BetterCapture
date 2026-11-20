//
//  CommandLineToolService.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import Foundation

/// Checks whether `bettercapture` can be run from the user's terminal.
///
/// Apps opened from Finder get a minimal `PATH`, so the check runs the user's login shell,
/// which reads the same startup files as a new terminal window.
@MainActor
@Observable
final class CommandLineToolService {

    nonisolated enum Status: Equatable {
        case checking
        /// `bettercapture` runs the tool inside this app
        case available
        /// `bettercapture` runs a different copy, such as from another BetterCapture install
        case otherCopy(path: String)
        /// Something else is at `~/.local/bin/bettercapture`, so the link couldn't be created
        case linkBlocked
        /// The link exists, but the shell doesn't search `~/.local/bin`
        case notOnPath
    }

    private(set) var status: Status = .checking

    /// The user's login shell, such as `/bin/zsh`
    let shellPath: String = {
        guard let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell else { return "/bin/zsh" }
        return String(cString: shell)
    }()

    /// The line that adds `~/.local/bin` to the `PATH`, and the file it belongs in, for the user's shell
    var pathSetup: (line: String, file: String) {
        switch URL(filePath: shellPath).lastPathComponent {
        case "fish": ("fish_add_path ~/.local/bin", "~/.config/fish/config.fish")
        case "bash": (#"export PATH="$HOME/.local/bin:$PATH""#, "~/.bash_profile")
        default: (#"export PATH="$HOME/.local/bin:$PATH""#, "~/.zprofile")
        }
    }

    func refresh() async {
        status = .checking
        let isLinked = CommandLineToolInstaller.installLink()
        let foundPath = await findInLoginShell()
        status = Self.status(foundPath: foundPath, isLinked: isLinked, toolURL: CommandLineToolInstaller.toolURL)
    }

    /// Compares the command the shell found with the tool inside this app
    /// - Parameter isLinked: Whether `~/.local/bin/bettercapture` points at the tool
    nonisolated static func status(foundPath: String?, isLinked: Bool, toolURL: URL) -> Status {
        guard let foundPath else { return isLinked ? .notOnPath : .linkBlocked }

        let resolved = URL(filePath: foundPath).resolvingSymlinksInPath()
        return resolved == toolURL.resolvingSymlinksInPath() ? .available : .otherCopy(path: resolved.path(percentEncoded: false))
    }

    private func findInLoginShell() async -> String? {
        let process = Process()
        process.executableURL = URL(filePath: shellPath)
        // Interactive as well as login, since many people set PATH in ~/.zshrc
        process.arguments = ["-l", "-i", "-c", "command -v bettercapture"]
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe

        let output = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
            process.terminationHandler = { _ in
                continuation.resume(returning: pipe.fileHandleForReading.readDataToEndOfFile())
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(returning: Data())
                return
            }

            // A startup file waiting for input must not leave the check hanging
            Task {
                try? await Task.sleep(for: .seconds(5))
                if process.isRunning {
                    process.terminate()
                }
            }
        }

        // Startup files may print their own output, so take the last line that is a path
        return (String(bytes: output, encoding: .utf8) ?? "")
            .split(separator: "\n")
            .last { $0.hasPrefix("/") }
            .map(String.init)
    }
}

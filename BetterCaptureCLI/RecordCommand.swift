//
//  RecordCommand.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

import ArgumentParser
import Dispatch
import Foundation

struct RecordCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Start a recording.",
        discussion: """
            Records the main display unless a target is given. Targets match an exact ID first, \
            then an exact name ignoring case, then part of a name. List them with the displays, \
            windows and apps commands.

            Recording uses the settings chosen in BetterCapture. Any number of recordings can \
            run at once. The recording's ID and output path are printed as soon as it starts.
            """
    )

    @Option(help: "Display to record: an ID, \"main\" or a name. With --area, the display the area is on.")
    var display: String?

    @Option(help: "Window to record: an ID or title.")
    var window: String?

    @Option(help: "App to record: a bundle identifier or name.")
    var app: String?

    @Option(help: ArgumentHelp("Area of a display to record, in points from its top-left corner.", valueName: "x,y,width,height"))
    var area: AreaArgument?

    @Option(help: "A name to tell the recording apart by. Other commands accept it in place of the ID.")
    var name: String?

    @Option(help: ArgumentHelp("Stop automatically after this long, such as 90, 30s, 2m or 1h.", valueName: "duration"))
    var duration: DurationArgument?

    @Flag(help: "Wait until the recording ends, then print the file's path. Ctrl-C stops and saves the recording.")
    var wait = false

    @OptionGroup var output: OutputOptions

    func validate() throws {
        if [window, app].compactMap({ $0 }).count + (area == nil ? 0 : 1) > 1 {
            throw ValidationError("Pass only one of --window, --app and --area.")
        }
        if display != nil, window != nil || app != nil {
            throw ValidationError("--display can't be combined with --window or --app.")
        }
    }

    private var target: CaptureTarget {
        if let window {
            .window(window)
        } else if let app {
            .app(app)
        } else if let area {
            .area(area.rect, display: display ?? "main")
        } else {
            .display(display ?? "main")
        }
    }

    func run() throws {
        let options = RecordOptions(target: target, name: name, durationSeconds: duration?.seconds)
        guard case .recording(let started) = try output.send(.record(options)) else { throw output.unexpectedResponse() }

        guard wait else {
            output.emit(started, human: started.text)
            return
        }

        if !output.json {
            output.printError("\(started.text). Press Ctrl-C to stop.")
        }

        let interruptSource = Self.stopOnInterrupt(started.id)
        defer { interruptSource.cancel() }

        guard case .recording(let recording) = try output.send(.wait(started.id), launchIfNeeded: false) else {
            throw output.unexpectedResponse()
        }
        output.emit(recording, human: recording.outputPath)
    }

    /// Stops the recording on the first Ctrl-C, so the wait ends with a saved file. A second
    /// Ctrl-C quits right away, in case BetterCapture doesn't respond.
    private static func stopOnInterrupt(_ recordingID: String) -> DispatchSourceSignal {
        signal(SIGINT, SIG_IGN)

        let source = DispatchSource.makeSignalSource(signal: SIGINT)
        source.setEventHandler {
            signal(SIGINT, SIG_DFL)
            _ = try? ControlClient.current().send(
                .stop(recordingID, all: false, copyToClipboard: false),
                launchIfNeeded: false
            )
        }
        source.resume()
        return source
    }
}

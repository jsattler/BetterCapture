//
//  SkillGuide.swift
//  BetterCaptureCLI
//
//  Created by Joshua Sattler on 20.11.26.
//

/// The usage guide printed by `bettercapture skill show`, written for AI agents
enum SkillGuide {

    /// - Parameter toolPath: The full path of this tool, for when `bettercapture` isn't on the `PATH`
    static func text(toolPath: String?) -> String {
        let fallback = toolPath.map {
            """

            If `bettercapture` isn't found, run it by its full path:

            ```sh
            '\($0)'
            ```

            """
        } ?? "\n"

        return guide.replacing("{{fallback}}", with: fallback)
    }

    private static let guide = """
        ---
        name: bettercapture
        description: Record the Mac's screen with BetterCapture. Use when asked to record the screen, a window, an app or an area, or to stop or check a recording.
        ---

        # BetterCapture

        Record the screen with the `bettercapture` command. The BetterCapture app does the
        recording, using the user's settings for codec, frame rate and audio. The command
        launches the app if it isn't running.
        {{fallback}}
        ## Before you start

        The user must turn on "Allow Command-Line Control" in BetterCapture Settings →
        Command Line. Until then every command exits with code 5 and error code `disabled`.
        Ask the user to turn it on. Don't try to change the setting yourself.

        ## Record

        Pass `--json` to every command and read the result from standard output.

        ```sh
        bettercapture record --json                              # the main display
        bettercapture record --app com.apple.Safari --json       # one app's windows
        bettercapture record --window 'Release Notes' --json     # one window, by title or ID
        bettercapture record --display main --area 0,0,800,600 --json   # x,y,width,height in points
        bettercapture record --name demo --json                  # a name to refer to it by
        ```

        `record` returns as soon as the recording starts. Its `id` identifies the recording,
        and `outputPath` already names the file it will be saved to. To end it:

        - Pass `--duration 30s` (or `90`, `2m`, `1h`) to stop automatically.
        - Run `bettercapture stop <id> --json`, which prints `outputPath` once the file is saved.
        - Run `bettercapture wait <id> --json` to block until it ends, however it ends.

        `record --duration 10s --wait --json` records, waits and prints the saved file in
        one step.

        ## Several recordings

        Any number of recordings can run at once, each with its own target. `stop`, `pause`,
        `resume`, `wait` and `status` take the recording's ID or name. Leaving it out works
        only while exactly one recording is in progress; otherwise the command exits with
        code 3 and lists the recordings in `error.candidates`. Prefer passing the ID.
        `bettercapture stop --all --json` stops every recording and returns `recordings`.

        Recordings started from the menu bar aren't visible here, and are never stopped by
        these commands.

        ## Find targets

        ```sh
        bettercapture displays --json
        bettercapture windows --json
        bettercapture apps --json
        ```

        Targets match an exact ID first, then an exact name ignoring case, then part of a
        name. When a query matches more than one target, the command exits with code 3 and
        lists the matches in `error.candidates`. Pass the ID of the one you want. Window IDs
        stay valid only while the window is open.

        ## Other commands

        - `bettercapture status --json` lists `recordings`: those in progress and the last
          50 that ended since BetterCapture started. Each has `id`, `name`, `state`
          (`recording`, `paused`, `stopping`, `finished` or `failed`), `target`, `startedAt`,
          `endedAt`, `durationSeconds`, `outputPath` and, when it failed, `error`.
          `status <id>` shows one.
        - `bettercapture pause <id>` and `bettercapture resume <id>`.
        - `bettercapture stop <id> --copy` also copies the file to the clipboard.

        ## Errors

        Errors go to standard error. With `--json` they look like
        `{"error": {"code": "...", "message": "..."}}`.

        | Exit code | Meaning |
        | --- | --- |
        | 0 | Success |
        | 1 | Failure, such as `not_recording` |
        | 2 | Invalid command line or area |
        | 3 | Target not found or ambiguous |
        | 4 | BetterCapture couldn't be reached |
        | 5 | Command-line control is off, or a macOS permission is missing |

        For code 5 with `permission_denied`, the user has to grant Screen Recording (or
        Microphone) access to BetterCapture in System Settings → Privacy & Security.
        """
}

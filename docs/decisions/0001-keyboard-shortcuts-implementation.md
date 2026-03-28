---
status: decided
date: 2026-03-28
decision-makers: jsattler
---

# Use sindresorhus/KeyboardShortcuts for global keyboard shortcuts

## Context and Problem Statement

BetterCapture has no keyboard shortcuts.
All actions (toggle recording, select content, select area) require clicking through the menu bar popover.
Users have requested global hotkeys that work even when the app is not focused (see [Discussion #76](https://github.com/jsattler/BetterCapture/discussions/76), [Issue #119](https://github.com/jsattler/BetterCapture/issues/119)).

## Decision Drivers

- BetterCapture is fully sandboxed (`com.apple.security.app-sandbox`) and must remain so for Mac App Store compatibility.
- Shortcuts must work globally (when the app is not focused), since the app is a menu bar agent (`LSUIElement = true`) with no persistent window.
- The solution should provide a native-feeling UI for users to customize their shortcuts.
- Conflict detection with system and app shortcuts is important.
- No Accessibility permission should be required (poor UX barrier).
- Minimal implementation effort — the project already has one third-party dependency (Sparkle).

## Considered Options

- sindresorhus/KeyboardShortcuts (third-party Swift package)
- NSEvent.addGlobalMonitorForEvents (native AppKit API)
- CGEvent.tapCreate / Quartz Event Services (native Core Graphics API)

## Decision Outcome

Chosen option: "sindresorhus/KeyboardShortcuts", because it is the only approach that supports global hotkeys in a sandboxed app without requiring Accessibility permission, while also providing a complete solution (recorder UI, conflict detection, UserDefaults storage).

### Consequences

- Good, because it works within the App Sandbox with no additional entitlements.
- Good, because it provides a SwiftUI `Recorder` view that handles shortcut recording, display, and conflict warnings.
- Good, because it stores shortcuts in `UserDefaults`, consistent with the existing `SettingsStore` pattern.
- Good, because it is well-maintained (2.6k stars, MIT license, latest release Sep 2025), used in production Mac App Store apps.
- Bad, because it introduces a second third-party dependency (alongside Sparkle).
- Bad, because it internally uses Carbon `RegisterEventHotKey`, which is legacy but has no modern replacement from Apple.

### Confirmation

- Verify that all three shortcuts (Toggle Recording, Select Content, Select Area) function globally when the app is not focused.
- Verify that the `KeyboardShortcuts.Recorder` views appear correctly in the Settings window.
- Verify that no Accessibility permission prompt is triggered.
- Verify that the app remains sandboxed and builds without additional entitlements.

## Pros and Cons of the Options

### sindresorhus/KeyboardShortcuts

A mature Swift package (macOS 10.15+) that wraps Carbon `RegisterEventHotKey` with a SwiftUI-native API. Provides a `Recorder` view for user-customizable shortcuts, automatic conflict detection, and `UserDefaults` persistence.

- Good, because fully sandboxed and Mac App Store compatible.
- Good, because no Accessibility permission required.
- Good, because provides SwiftUI `Recorder` view with built-in conflict detection.
- Good, because supports `@Observable` pattern via `onKeyUp(for:)` callbacks.
- Good, because handles storage, display, and localization out of the box.
- Neutral, because adds a third-party dependency (MIT license, well-maintained).
- Bad, because relies on Carbon APIs internally (no modern Apple replacement exists).

### NSEvent.addGlobalMonitorForEvents

Native AppKit API that installs a monitor for events posted to other applications.

- Good, because it is a first-party Apple API with no third-party dependency.
- Bad, because key events require Accessibility permission ("Key-related events may only be monitored if accessibility is enabled or if your application is trusted for accessibility access").
- Bad, because events can only be observed, not consumed (the shortcut passes through to the focused app).
- Bad, because no built-in recorder UI, conflict detection, or storage — all must be built from scratch.
- Bad, because the Accessibility permission requirement is a significant UX barrier.

### CGEvent.tapCreate / Quartz Event Services

Low-level Core Graphics API for creating event taps that intercept input events at the system level.

- Good, because it provides the most control over event handling (can modify or consume events).
- Bad, because it is not compatible with App Sandbox — requires the process to be trusted for accessibility.
- Bad, because it is designed for assistive technology (Section 508), not general app hotkeys.
- Bad, because it is significantly more complex to implement than the alternatives.
- Bad, because it would require removing the sandbox entitlement, breaking Mac App Store eligibility.

## More Information

### Shortcuts to implement

| Shortcut Name    | Action                          | ViewModel Method         |
| ---------------- | ------------------------------- | ------------------------ |
| Toggle Recording | Start or stop recording         | `toggleRecording()`      |
| Select Content   | Open the system content picker  | `presentPicker()`        |
| Select Area      | Open the area selection overlay | `presentAreaSelection()` |

### UX decisions

- **No default key combinations.** All shortcuts start unconfigured. Users set their own in a new "Shortcuts" tab in Settings. This follows the library author's recommendation: "please do not set this for a publicly distributed app. Users find it annoying when random apps steal their existing keyboard shortcuts."
- **Toggle Recording** instead of separate Start/Stop. A single shortcut toggles between starting and stopping a recording, reducing cognitive load.
- **Smart Toggle Recording behavior:** When the user triggers Toggle Recording and no content is selected, it automatically triggers the appropriate selection flow based on the user's current `ContentSelectionMode` preference (stored in `@AppStorage("contentSelectionMode")`). If mode is `.pickContent`, it calls `presentPicker()`. If mode is `.selectArea`, it calls `presentAreaSelection()`. If content is already selected and recording is idle, it starts recording. If recording is active, it stops.
- The `KeyboardShortcuts.Recorder` view automatically warns users when a chosen shortcut conflicts with system shortcuts (e.g., Shift+Cmd+4 for screenshots) or the app's own menu shortcuts.

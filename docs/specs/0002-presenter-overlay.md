# Presenter Overlay

> Enable Presenter Overlay support so users can embed their camera feed into screen recordings.

## Why

Screen recordings often lack a personal touch. macOS provides Presenter Overlay, a system-level feature that composites the presenter's camera feed on top of shared content (small movable window or large immersive mode). BetterCapture currently has no camera integration, so Presenter Overlay is unavailable. Adding camera support enables this feature automatically through the system's Video menu bar item.

## Expected outcome

- A new "Presenter Overlay" toggle appears in the menu bar settings under a "Camera" section.
- When enabled and a recording starts, BetterCapture starts an `AVCaptureSession` for the selected camera.
- The system detects the active camera + `SCStream` combination and enables Presenter Overlay controls in the macOS Video menu bar item.
- The user controls overlay mode (small/large/off) through the system Video menu bar — BetterCapture does not need its own overlay controls.
- Composited frames (screen content + camera overlay) arrive through the existing `SCStream` pipeline with no changes to the recording/encoding path.
- A camera picker (similar to the existing microphone picker) lets the user select which camera to use.
- A status indicator appears during recording when Presenter Overlay is active.
- Camera permission is requested when the feature is first enabled.

## Approach

### How Presenter Overlay works

Presenter Overlay is not an API you call directly. It is a system-level video effect that activates automatically when:

1. An `SCStream` is actively capturing content via ScreenCaptureKit.
2. The same application has an active `AVCaptureSession` using a camera.

When both conditions are met, macOS offers Presenter Overlay controls in the system Video menu bar item. Once the user enables it there, ScreenCaptureKit composites the camera feed into the stream frames automatically. The composited frames arrive through the existing `SCStreamOutput` — no changes to the frame processing pipeline are needed.

Key API surface:

- `SCStreamDelegate.outputVideoEffectDidStart(for:)` / `outputVideoEffectDidStop(for:)` — delegate callbacks that notify when Presenter Overlay is activated/deactivated by the user.
- `SCStreamConfiguration.presenterOverlayPrivacyAlertSetting` — controls whether a privacy alert is shown (default: `.system`). We keep the default.
- `SCStreamFrameInfo.presenterOverlayContentRect` — available in frame metadata, provides the rect where the shared content is rendered (useful if the app needs to know the layout). Not needed for recording.

### Camera selection

Camera selection uses `AVCaptureDevice.DiscoverySession` to enumerate available cameras, the same pattern used by `AudioDeviceService` for microphones. The user selects a camera in the menu bar popover, and the selected device ID is stored in `SettingsStore`.

The camera session itself does not need to output frames to the app. It only needs to be running so the system detects it and enables Presenter Overlay. A minimal `AVCaptureSession` with a video input (no output) is sufficient.

### Permissions

Camera access requires:

1. **Entitlement**: `com.apple.security.device.camera` in `BetterCapture.entitlements`.
2. **Usage description**: `NSCameraUsageDescription` in `Info.plist`.
3. **Runtime permission**: `AVCaptureDevice.requestAccess(for: .video)` — prompted when the user first enables the Presenter Overlay toggle.

### Camera session lifecycle

- The `AVCaptureSession` starts when recording begins (if Presenter Overlay is enabled in settings).
- The session stops when recording stops.
- If the selected camera becomes unavailable, fall back to the default camera.

### UI changes

1. **MenuBarSettingsView** — Add a new "Camera" section between the existing Video and Audio sections:
   - "Presenter Overlay" toggle (`MenuBarToggle`) — enables/disables the camera session during recording.
   - Camera picker (`CameraExpandablePicker`, modeled on `MicrophoneExpandablePicker`) — shown only when the toggle is on. Lists available cameras with "System Default" as the first option.

2. **MenuBarView** (recording state) — When Presenter Overlay is active (detected via delegate callbacks), show a small status indicator (e.g., a camera icon or text label) in the recording controls area.

3. **SettingsView** — No changes needed. The settings window currently mirrors menu bar toggles, but camera settings are scoped to the menu bar popover for now.

### Model changes

4. **SettingsStore** — Add:
   - `presenterOverlayEnabled: Bool` (default: `false`, persisted via `UserDefaults` key `"presenterOverlayEnabled"`).
   - `selectedCameraID: String?` (default: `nil`, persisted via `UserDefaults` key `"selectedCameraID"`). `nil` means system default.

### Service changes

5. **CameraService** (new file) — `@MainActor @Observable final class CameraService`:
   - Enumerates available cameras using `AVCaptureDevice.DiscoverySession` with device types `.builtInWideAngleCamera` and `.external`, media type `.video`.
   - Monitors camera connect/disconnect via `AVCaptureDevice` notifications.
   - Manages an `AVCaptureSession`:
     - `startSession(deviceID: String?)` — creates session, adds video input for the selected (or default) camera, starts running.
     - `stopSession()` — stops and tears down the session.
   - Exposes `availableCameras: [CameraDevice]` (id, name, isDefault) and `isSessionRunning: Bool`.

6. **CameraDevice** (in CameraService or its own file) — Simple struct:
   ```swift
   struct CameraDevice: Identifiable {
       let id: String
       let name: String
       let isDefault: Bool
   }
   ```

7. **PermissionService** — Add:
   - `cameraState: PermissionState` property.
   - `checkCameraPermission() -> PermissionState` — uses `AVCaptureDevice.authorizationStatus(for: .video)`.
   - `requestCameraPermission() async` — uses `AVCaptureDevice.requestAccess(for: .video)`.
   - `openCameraSettings()` — opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Camera`.
   - Update `allPermissionsGranted` and `hasAnyPermissionDenied` to include camera state (only when `presenterOverlayEnabled`).

8. **CaptureEngine** — Add:
   - Implement `SCStreamDelegate.outputVideoEffectDidStart(for:)` and `outputVideoEffectDidStop(for:)`.
   - Expose `isPresenterOverlayActive: Bool` (updated from the delegate callbacks).
   - Forward overlay state changes to `CaptureEngineDelegate` via a new method: `captureEnginePresenterOverlayDidChange(_ engine: CaptureEngine, isActive: Bool)`.

9. **RecorderViewModel** — Update:
   - In `startRecording()`: if `settings.presenterOverlayEnabled`, start `CameraService.startSession()` before starting the `SCStream`.
   - In `stopRecording()`: stop `CameraService.stopSession()` after stopping the stream.
   - Track `isPresenterOverlayActive` from `CaptureEngineDelegate` for the UI indicator.

### Configuration

The `presenterOverlayPrivacyAlertSetting` on `SCStreamConfiguration` is left at its default value (`.system`). No user-facing setting is exposed for this.

## File changes

| File | Change |
|------|--------|
| `BetterCapture.entitlements` | Add `com.apple.security.device.camera` entitlement |
| `Info.plist` | Add `NSCameraUsageDescription` usage string |
| `Model/SettingsStore.swift` | Add `presenterOverlayEnabled` and `selectedCameraID` properties |
| `Service/CameraService.swift` | **New file** — camera enumeration and `AVCaptureSession` management |
| `Service/PermissionService.swift` | Add camera permission check/request/open methods and `cameraState` property |
| `Service/CaptureEngine.swift` | Implement `outputVideoEffectDidStart`/`Stop` delegate methods, expose `isPresenterOverlayActive`, update `CaptureEngineDelegate` |
| `ViewModel/RecorderViewModel.swift` | Start/stop camera session with recording, track overlay active state |
| `View/MenuBarSettingsView.swift` | Add "Camera" section with Presenter Overlay toggle and camera picker |
| `View/MenuBarView.swift` | Add Presenter Overlay active indicator during recording |

## Constraints

- Requires macOS 14.0+ (Presenter Overlay was introduced in macOS Sonoma / ScreenCaptureKit additions in WWDC23).
- The camera session does not need to produce output frames — it only needs to be running for the system to detect it.
- Presenter Overlay compositing happens at the system level. The composited frames arrive through the existing `SCStream` output with no changes to `AssetWriter` or the encoding pipeline.
- Area selection recordings support Presenter Overlay — the overlay is composited into whatever region is being captured.
- Camera selection is independent of microphone selection. They use the same UI pattern but different device discovery sessions.

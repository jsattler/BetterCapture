# Area Selection Recording

> Allow users to draw a rectangle on a display and record only that region.

## Why

Currently BetterCapture relies on `SCContentSharingPicker` which limits content selection to full displays, windows, or applications. Users often need to record a specific region of the screen (e.g., a portion of a webpage, a panel in an IDE, or a UI demo area) without capturing the entire display or window. This feature fills that gap.

## Expected outcome

- A new "Select Area" button appears alongside the existing "Select Content" button in the menu bar popover.
- Clicking "Select Area" shows a translucent overlay on the display under the mouse cursor.
- The user draws a rectangle by clicking and dragging on the overlay.
- After drawing, the user can reposition (drag) or resize (drag corner/edge handles) the rectangle before confirming.
- Pressing Enter or clicking a confirm button accepts the selection; pressing Escape cancels it.
- Once confirmed, the menu bar popover shows a preview thumbnail of the selected area and the "Start Recording" button becomes enabled.
- Recording captures only the selected rectangle of the display.
- The overlay disappears once the selection is confirmed (no visible border during recording).

## Approach

### Key API: `SCStreamConfiguration.sourceRect`

The `sourceRect` property on `SCStreamConfiguration` specifies a sub-region of the display to capture. Important constraints from Apple's documentation:

- `sourceRect` only works with **display captures** (not window or application captures).
- Coordinates are in the display's native coordinate space (points).
- If `sourceRect` is not set, the full display is captured.

### UI changes

1. **MenuBarView** - Add a "Select Area" button next to the existing "Select Content" button. When an area selection is active, show "Change Area" instead.
   - Update the existing "Select Content" button icon from `rectangle.dashed` to `macwindow` (an application-style icon, since it selects windows/apps/displays via the system picker).
   - The new "Select Area" button uses `rectangle.dashed` (the current icon, which visually represents drawing a rectangle region).
2. **AreaSelectionOverlay** - A new `NSWindow`/`NSPanel` subclass (borderless, transparent, full-screen on the target display) that:
   - Dims the screen with a translucent overlay.
   - Lets the user draw a rectangle via click-and-drag.
   - Shows resize handles (corners + edges) and allows repositioning after the initial draw.
   - Displays the pixel dimensions of the selection as a label near the rectangle.
   - Confirms on Enter / double-click, cancels on Escape.
   - Uses `NSWindow.Level.screenSaver` (or similar) to float above all content.
3. **PreviewThumbnailView** - No changes needed; the preview service will receive the display filter and `sourceRect` will crop the preview automatically.

### Model changes

4. **RecorderViewModel** - Add:
   - `selectedSourceRect: CGRect?` property to store the user's area selection.
   - `presentAreaSelection()` method that determines the display under the cursor (via `NSEvent.mouseLocation` and `NSScreen.screens`), creates the overlay window, and awaits the result.
   - `clearAreaSelection()` method that resets `selectedSourceRect` and clears the associated display filter.
   - When an area is confirmed, create an `SCContentFilter` for the detected display and store `selectedSourceRect`.

### Service changes

5. **CaptureEngine** - Modify `createStreamConfiguration(from:contentSize:)` to accept an optional `sourceRect: CGRect?` parameter. When provided, set `config.sourceRect` and adjust `config.width`/`config.height` to match the source rect dimensions (scaled by the display's `backingScaleFactor`).
6. **CaptureEngine** - Modify `startCapture(with:videoSize:)` to accept the optional `sourceRect` and pass it to `createStreamConfiguration`.
7. **PreviewService** - Modify `createPreviewConfiguration()` and `captureStaticThumbnail(for:)` to accept an optional `sourceRect: CGRect?` and apply it to the `SCStreamConfiguration` so the preview shows only the selected area.
8. **RecorderViewModel** - Update `getContentSize(from:)` to use `selectedSourceRect` dimensions (scaled) when an area selection is active, instead of the full display `contentRect`.
9. **RecorderViewModel** - Update `startRecording()` to pass `selectedSourceRect` through to the capture engine.

### Display detection

10. When the user clicks "Select Area":
    - Read `NSEvent.mouseLocation` (in global screen coordinates).
    - Find the matching `NSScreen` from `NSScreen.screens` using `frame.contains()`.
    - Query `SCShareableContent.current` for the corresponding `SCDisplay` (match by `displayID` from `screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]`).
    - Create the overlay on that screen and, upon confirmation, build an `SCContentFilter(display:excludingWindows: [])` for that display.

### Coordinate mapping

11. The overlay captures the rectangle in the `NSScreen` coordinate space (points, origin at bottom-left). `sourceRect` uses the display's coordinate space (points, origin at top-left). The conversion is:
    - `sourceRect.origin.x` = overlay rect origin x relative to the display.
    - `sourceRect.origin.y` = display height - overlay rect origin y - overlay rect height (flip Y axis).
    - Width and height remain the same.

### Content filter interaction

12. Area selection and content picker selection are mutually exclusive:
    - Selecting an area clears any existing `SCContentSharingPicker` selection.
    - Using `SCContentSharingPicker` clears any existing area selection.
    - The UI reflects which mode is active.

## File changes

| File | Change |
|------|--------|
| `View/MenuBarView.swift` | Add "Select Area" / "Change Area" button |
| `View/AreaSelectionOverlay.swift` | **New file** - NSPanel subclass for the rectangle drawing overlay |
| `ViewModel/RecorderViewModel.swift` | Add `selectedSourceRect`, `presentAreaSelection()`, `clearAreaSelection()`, update `startRecording()` and `getContentSize()` |
| `Service/CaptureEngine.swift` | Accept `sourceRect` in `startCapture` and `createStreamConfiguration` |
| `Service/PreviewService.swift` | Accept `sourceRect` in preview configuration methods |

## Constraints

- Minimum selection size is 24x24 points to prevent accidental tiny selections.
- Selection dimensions are snapped to even pixel counts to avoid codec issues with odd dimensions.

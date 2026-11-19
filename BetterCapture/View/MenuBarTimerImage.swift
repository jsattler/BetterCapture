//
//  MenuBarTimerImage.swift
//  BetterCapture
//

import AppKit

/// Renders the recording duration for the menu bar status item.
///
/// Shared by the SwiftUI menu bar label (comfortable layout) and the AppKit
/// status item (compact layout).
enum MenuBarTimerImage {

    /// Renders the formatted duration into an ``NSImage`` with a stable
    /// width derived from the widest possible string for the current format,
    /// so the status item never recalculates its width on each tick.
    static func make(text: String, recordingDuration: TimeInterval) -> NSImage {
        // Use the widest possible string for the current format to
        // compute a stable size that won't change between ticks.
        let referenceText: String = if recordingDuration >= 3600 {
            "0:00:00"
        } else {
            "00:00"
        }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let referenceSize = (referenceText as NSString).size(withAttributes: attrs)
        let imageSize = NSSize(width: ceil(referenceSize.width), height: ceil(referenceSize.height))

        let textSize = (text as NSString).size(withAttributes: attrs)
        let origin = NSPoint(
            x: (imageSize.width - textSize.width) / 2,
            y: (imageSize.height - textSize.height) / 2
        )

        let image = NSImage(size: imageSize, flipped: false) { _ in
            (text as NSString).draw(at: origin, withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        return image
    }
}

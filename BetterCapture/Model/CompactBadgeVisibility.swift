//
//  CompactBadgeVisibility.swift
//  BetterCapture
//

import Foundation

/// Decides when the floating compact badge is on screen.
///
/// The badge starts hidden and behaves like a menu: clicking the menu bar icon
/// toggles it, and it hides again after an action, on Escape, or when a
/// recording starts or stops.
struct CompactBadgeVisibility {
    private(set) var isShown = false

    func isVisible(layoutMode: LayoutMode) -> Bool {
        layoutMode == .compact && isShown
    }

    /// Handles a click on the menu bar icon
    mutating func toggle() {
        isShown.toggle()
    }

    /// Handles an action in the badge, or Escape
    mutating func hide() {
        isShown = false
    }

    /// Starting or stopping a recording hides the badge
    mutating func recordingStateDidChange() {
        isShown = false
    }
}

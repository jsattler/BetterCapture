//
//  SettingsNavigation.swift
//  BetterCapture
//

/// Tracks the selected settings pane with browser-style back/forward history
struct SettingsNavigation {
    private(set) var current: SettingsPane = .general
    private var backStack: [SettingsPane] = []
    private var forwardStack: [SettingsPane] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Selects a pane, recording the previous one and clearing forward history
    mutating func visit(_ pane: SettingsPane) {
        guard pane != current else { return }
        backStack.append(current)
        forwardStack.removeAll()
        current = pane
    }

    mutating func goBack() {
        guard let pane = backStack.popLast() else { return }
        forwardStack.append(current)
        current = pane
    }

    mutating func goForward() {
        guard let pane = forwardStack.popLast() else { return }
        backStack.append(current)
        current = pane
    }
}

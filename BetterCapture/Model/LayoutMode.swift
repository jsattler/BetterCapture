//
//  LayoutMode.swift
//  BetterCapture
//

import Foundation

/// How BetterCapture presents its controls
enum LayoutMode: String, CaseIterable, Identifiable {
    /// The `UserDefaults` / `@AppStorage` key used to persist the layout mode.
    static let storageKey = "layoutMode"

    /// The full menu bar window with all settings
    case comfortable
    /// A small floating badge with only the essential actions
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .comfortable: "Comfortable"
        case .compact: "Compact"
        }
    }
}

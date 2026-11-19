//
//  TargetResolver.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 20.11.26.
//

import CoreGraphics
import Foundation

/// Matches a target query from the command line against the available displays, windows
/// or applications.
///
/// A query is matched in three passes, stopping at the first pass that matches anything:
/// the exact ID, the exact name ignoring case, and finally a name containing the query.
/// More than one match in a pass is ambiguous, so nothing is ever recorded by guessing.
enum TargetResolver {

    struct Candidate<Item> {
        var item: Item
        var id: String
        var name: String
    }

    static func resolve<Item>(_ query: String, in candidates: [Candidate<Item>], kind: String) throws(ControlError) -> Item {
        let passes: [(Candidate<Item>) -> Bool] = [
            { $0.id == query },
            { $0.name.compare(query, options: .caseInsensitive) == .orderedSame },
            { $0.name.localizedStandardContains(query) }
        ]

        for pass in passes {
            let matches = candidates.filter(pass)

            if matches.count == 1 {
                return matches[0].item
            }

            if matches.count > 1 {
                throw ControlError(
                    code: .ambiguous,
                    message: "\"\(query)\" matches \(matches.count) \(kind)s. Pass an ID instead.",
                    candidates: matches.map { "\($0.id)\t\($0.name)" }
                )
            }
        }

        throw ControlError(code: .notFound, message: "No \(kind) matches \"\(query)\".")
    }

    /// Converts an area on a display into the source rectangle to capture.
    ///
    /// The width and height are rounded up to an even number of pixels, as codecs require,
    /// the same way the interactive area selection does.
    /// - Parameters:
    ///   - area: The area in points, relative to the display's top-left corner
    ///   - displaySize: The display's size in points
    ///   - scale: The display's backing scale factor
    static func sourceRect(for area: AreaRect, displaySize: CGSize, scale: CGFloat) throws(ControlError) -> CGRect {
        let rect = CGRect(x: area.left, y: area.top, width: area.width, height: area.height)
        let bounds = CGRect(origin: .zero, size: displaySize)

        guard rect.width > 0, rect.height > 0, bounds.contains(rect) else {
            throw ControlError(
                code: .invalidRequest,
                message: "The area must have a positive size and fit within the \(Int(displaySize.width))x\(Int(displaySize.height)) display."
            )
        }

        let evenPixelWidth = ceil(rect.width * scale / 2) * 2
        let evenPixelHeight = ceil(rect.height * scale / 2) * 2

        return CGRect(x: rect.minX, y: rect.minY, width: evenPixelWidth / scale, height: evenPixelHeight / scale)
    }
}

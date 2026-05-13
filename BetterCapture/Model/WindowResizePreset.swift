//
//  WindowResizePreset.swift
//  BetterCapture
//
//  Created by Karel Busta on 13.05.26.
//

import CoreGraphics

/// Common target sizes for preparing a selected window before recording.
enum WindowResizePreset: String, CaseIterable, Identifiable {
    case portrait720
    case portrait1080
    case landscape720
    case landscape1080
    case square1080

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait720:
            "9:16 720x1280"
        case .portrait1080:
            "9:16 1080x1920"
        case .landscape720:
            "16:9 1280x720"
        case .landscape1080:
            "16:9 1920x1080"
        case .square1080:
            "1:1 1080x1080"
        }
    }

    var size: CGSize {
        switch self {
        case .portrait720:
            CGSize(width: 720, height: 1280)
        case .portrait1080:
            CGSize(width: 1080, height: 1920)
        case .landscape720:
            CGSize(width: 1280, height: 720)
        case .landscape1080:
            CGSize(width: 1920, height: 1080)
        case .square1080:
            CGSize(width: 1080, height: 1080)
        }
    }
}

/// Pure frame calculation for fitting resize presets onto the visible screen.
enum WindowResizeLayout {
    static let defaultMargin: CGFloat = 24

    private static let minimumDimension: CGFloat = 160

    static func targetFrame(
        for preset: WindowResizePreset,
        currentFrame: CGRect,
        visibleFrame: CGRect,
        margin: CGFloat = defaultMargin
    ) -> CGRect {
        let bounds = clampedBounds(from: visibleFrame, margin: margin)
        guard bounds.width > 0, bounds.height > 0 else { return .zero }

        let targetSize = preset.size.fittingWithin(bounds.size)
        return frame(centeredOn: currentFrame.center, size: targetSize, clampedTo: bounds)
    }

    private static func clampedBounds(from visibleFrame: CGRect, margin: CGFloat) -> CGRect {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return .zero }

        let safeMargin = max(0, margin)
        let horizontalInset = min(safeMargin, max(0, (visibleFrame.width - minimumDimension) / 2))
        let verticalInset = min(safeMargin, max(0, (visibleFrame.height - minimumDimension) / 2))

        return visibleFrame.insetBy(dx: horizontalInset, dy: verticalInset)
    }

    private static func frame(centeredOn center: CGPoint, size: CGSize, clampedTo bounds: CGRect) -> CGRect {
        let width = min(size.width, bounds.width).rounded(.down)
        let height = min(size.height, bounds.height).rounded(.down)

        let originX: CGFloat
        if bounds.width <= width {
            originX = bounds.minX
        } else {
            originX = min(max(center.x - width / 2, bounds.minX), bounds.maxX - width)
        }

        let originY: CGFloat
        if bounds.height <= height {
            originY = bounds.minY
        } else {
            originY = min(max(center.y - height / 2, bounds.minY), bounds.maxY - height)
        }

        return CGRect(
            x: originX.rounded(),
            y: originY.rounded(),
            width: width,
            height: height
        )
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private extension CGSize {
    func fittingWithin(_ bounds: CGSize) -> CGSize {
        if width <= bounds.width, height <= bounds.height {
            return self
        }

        return fittingAspect(in: bounds)
    }

    private func fittingAspect(in bounds: CGSize) -> CGSize {
        guard width > 0, height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }

        let scale = min(bounds.width / width, bounds.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
}

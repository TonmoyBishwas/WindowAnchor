import AppKit

/// A snap target derived from the cursor's position near screen edges.
enum EdgeZone: Equatable {
    case flyout            // top-center hot zone: opens the layout picker
    case maximize
    case leftHalf
    case rightHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter

    /// The zone's cell, expressed like a layout cell (normalized).
    var cell: LayoutCell? {
        switch self {
        case .flyout: return nil
        case .maximize: return LayoutCell(x: 0, y: 0, w: 1, h: 1)
        case .leftHalf: return LayoutCell(x: 0, y: 0, w: 0.5, h: 1)
        case .rightHalf: return LayoutCell(x: 0.5, y: 0, w: 0.5, h: 1)
        case .topLeftQuarter: return LayoutCell(x: 0, y: 0, w: 0.5, h: 0.5)
        case .topRightQuarter: return LayoutCell(x: 0.5, y: 0, w: 0.5, h: 0.5)
        case .bottomLeftQuarter: return LayoutCell(x: 0, y: 0.5, w: 0.5, h: 0.5)
        case .bottomRightQuarter: return LayoutCell(x: 0.5, y: 0.5, w: 0.5, h: 0.5)
        }
    }
}

enum EdgeZones {
    static let edgeThreshold: CGFloat = 8
    static let cornerReach: CGFloat = 140
    static let flyoutZoneWidth: CGFloat = 420
    static let flyoutZoneHeight: CGFloat = 12

    /// The top-center hot zone that summons the layout flyout, in CG
    /// coordinates of the given screen frame.
    static func flyoutHotZone(screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.midX - flyoutZoneWidth / 2,
            y: screenFrame.minY,
            width: flyoutZoneWidth,
            height: flyoutZoneHeight
        )
    }

    /// Classifies a cursor location (CG coordinates) against a screen frame.
    static func zone(at point: CGPoint, screenFrame frame: CGRect,
                     preferences: Preferences) -> EdgeZone? {
        guard frame.insetBy(dx: -1, dy: -1).contains(point) else { return nil }

        if preferences.layoutFlyoutEnabled, flyoutHotZone(screenFrame: frame).contains(point) {
            return .flyout
        }

        let nearLeft = point.x - frame.minX <= edgeThreshold
        let nearRight = frame.maxX - point.x <= edgeThreshold
        let nearTop = point.y - frame.minY <= edgeThreshold
        let nearBottom = frame.maxY - point.y <= edgeThreshold

        // Corners take priority over plain edges: touching a vertical edge
        // within `cornerReach` of the top or bottom snaps a quarter.
        if preferences.cornerSnapEnabled {
            if nearLeft, point.y - frame.minY <= cornerReach { return .topLeftQuarter }
            if nearLeft, frame.maxY - point.y <= cornerReach { return .bottomLeftQuarter }
            if nearRight, point.y - frame.minY <= cornerReach { return .topRightQuarter }
            if nearRight, frame.maxY - point.y <= cornerReach { return .bottomRightQuarter }
        }

        if preferences.edgeSnapEnabled {
            if nearLeft { return .leftHalf }
            if nearRight { return .rightHalf }
        }
        if preferences.topEdgeMaximizes, nearTop, !nearBottom {
            return .maximize
        }
        return nil
    }
}

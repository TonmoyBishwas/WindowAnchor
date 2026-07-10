import AppKit

/// Pure geometry for turning normalized layout cells into absolute window
/// frames, honoring the user's gap and padding settings.
enum SnapEngine {
    /// Absolute frame (CG coordinates) for one cell of a layout applied to a
    /// screen's visible area. Gaps are applied half-per-side on interior
    /// edges so adjacent cells end up exactly `gap` points apart.
    static func frame(for cell: LayoutCell, in visibleFrame: CGRect,
                      gap: CGFloat, outerPadding: CGFloat) -> CGRect {
        let area = visibleFrame.insetBy(dx: outerPadding, dy: outerPadding)
        var rect = CGRect(
            x: area.minX + cell.x * area.width,
            y: area.minY + cell.y * area.height,
            width: cell.w * area.width,
            height: cell.h * area.height
        )

        let epsilon = 0.001
        let half = gap / 2
        // Interior edges get half the gap; edges flush with the area do not.
        if cell.x > epsilon { rect.origin.x += half; rect.size.width -= half }
        if cell.x + cell.w < 1 - epsilon { rect.size.width -= half }
        if cell.y > epsilon { rect.origin.y += half; rect.size.height -= half }
        if cell.y + cell.h < 1 - epsilon { rect.size.height -= half }

        return rect.integral
    }

    /// Snaps a window into a cell on the given screen.
    static func snap(window: AXWindow, cell: LayoutCell, on screen: NSScreen,
                     preferences: Preferences) {
        let target = frame(for: cell, in: Coords.visibleFrameCG(of: screen),
                           gap: preferences.windowGap, outerPadding: preferences.outerPadding)
        window.setFrame(target)
    }
}

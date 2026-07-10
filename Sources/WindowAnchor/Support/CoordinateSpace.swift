import AppKit

/// Conversions between CG global coordinates (top-left origin, y down — used by
/// the event tap and the Accessibility API) and AppKit screen coordinates
/// (bottom-left origin, y up — used to place NSWindows/NSPanels).
enum Coords {
    private static var primaryScreenHeight: CGFloat {
        // The primary screen is the one whose AppKit frame has origin (0,0).
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 0
    }

    static func cgToAppKit(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryScreenHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    static func appKitToCG(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX,
               y: primaryScreenHeight - rect.maxY,
               width: rect.width,
               height: rect.height)
    }

    static func cgToAppKit(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// The screen containing a point given in CG global coordinates.
    static func screen(containingCGPoint point: CGPoint) -> NSScreen? {
        let appKitPoint = cgToAppKit(point)
        return NSScreen.screens.first { $0.frame.contains(appKitPoint) }
            ?? NSScreen.main
    }

    /// A screen's usable area (excluding menu bar and Dock) in CG coordinates.
    static func visibleFrameCG(of screen: NSScreen) -> CGRect {
        appKitToCG(screen.visibleFrame)
    }

    /// A screen's full frame in CG coordinates.
    static func frameCG(of screen: NSScreen) -> CGRect {
        appKitToCG(screen.frame)
    }
}

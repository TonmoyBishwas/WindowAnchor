import AppKit
import SwiftUI

/// A borderless, non-activating panel that floats above normal windows.
/// Used for the layout flyout, snap previews, and Snap Assist.
final class OverlayPanel: NSPanel {
    init(level: NSWindow.Level = .statusBar, acceptsMouse: Bool = false) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        self.level = level
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = !acceptsMouse
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Places the panel at a frame given in CG global coordinates.
    func setFrameCG(_ cgFrame: CGRect) {
        setFrame(Coords.cgToAppKit(cgFrame), display: true)
    }

    func setContent<V: View>(_ view: V) {
        contentView = NSHostingView(rootView: view)
    }
}

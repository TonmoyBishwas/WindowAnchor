import AppKit
import SwiftUI

/// Translucent preview of where a window will land when dropped (edge snap).
final class SnapPreviewController {
    private let panel = OverlayPanel(level: .floating, acceptsMouse: false)
    private(set) var isVisible = false

    init() {
        panel.setContent(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 2)
                )
                .padding(2)
        )
    }

    /// Shows (or moves) the preview to a frame in CG coordinates.
    func show(frameCG: CGRect) {
        panel.setFrameCG(frameCG)
        if !isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 1
            }
            isVisible = true
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        panel.orderOut(nil)
    }
}

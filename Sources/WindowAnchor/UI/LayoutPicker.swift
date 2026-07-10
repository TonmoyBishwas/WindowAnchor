import AppKit
import SwiftUI

/// Fixed metrics for the flyout, shared by the SwiftUI view and the
/// cursor hit-testing done from event-tap coordinates (the user is holding a
/// drag, so the panel never receives real mouse events).
struct PickerGeometry {
    static let columns = 3
    static let tileWidth: CGFloat = 128
    static let tileHeight: CGFloat = 80
    static let tileSpacing: CGFloat = 10
    static let padding: CGFloat = 14
    static let cellInset: CGFloat = 3

    let layoutCount: Int

    var rows: Int { max(1, Int(ceil(Double(layoutCount) / Double(Self.columns)))) }
    var columnsInUse: Int { min(layoutCount, Self.columns) }

    var panelSize: CGSize {
        CGSize(
            width: CGFloat(columnsInUse) * Self.tileWidth
                + CGFloat(max(0, columnsInUse - 1)) * Self.tileSpacing
                + Self.padding * 2,
            height: CGFloat(rows) * Self.tileHeight
                + CGFloat(max(0, rows - 1)) * Self.tileSpacing
                + Self.padding * 2
        )
    }

    /// Frame of a layout tile in panel-local coordinates (top-left origin).
    func tileFrame(index: Int) -> CGRect {
        let row = index / Self.columns
        let col = index % Self.columns
        return CGRect(
            x: Self.padding + CGFloat(col) * (Self.tileWidth + Self.tileSpacing),
            y: Self.padding + CGFloat(row) * (Self.tileHeight + Self.tileSpacing),
            width: Self.tileWidth,
            height: Self.tileHeight
        )
    }

    /// Frame of one cell within a tile, in panel-local coordinates.
    func cellFrame(tileIndex: Int, cell: LayoutCell) -> CGRect {
        let tile = tileFrame(index: tileIndex).insetBy(dx: Self.cellInset, dy: Self.cellInset)
        return CGRect(
            x: tile.minX + cell.x * tile.width,
            y: tile.minY + cell.y * tile.height,
            width: cell.w * tile.width,
            height: cell.h * tile.height
        ).insetBy(dx: 1.5, dy: 1.5)
    }

    /// The (layout, cell) under a panel-local point, if any.
    func hitTest(_ point: CGPoint, layouts: [SnapLayout]) -> PickerTarget? {
        for (i, layout) in layouts.enumerated() {
            guard tileFrame(index: i).contains(point) else { continue }
            for (j, cell) in layout.cells.enumerated() {
                if cellFrame(tileIndex: i, cell: cell).insetBy(dx: -2, dy: -2).contains(point) {
                    return PickerTarget(layoutIndex: i, cellIndex: j)
                }
            }
            return nil
        }
        return nil
    }
}

struct PickerTarget: Equatable {
    var layoutIndex: Int
    var cellIndex: Int
}

final class PickerState: ObservableObject {
    @Published var layouts: [SnapLayout] = []
    @Published var hover: PickerTarget?
}

/// Windows-11-style grid of layout previews shown while dragging a window.
struct LayoutPickerView: View {
    @ObservedObject var state: PickerState

    var body: some View {
        let geometry = PickerGeometry(layoutCount: state.layouts.count)
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(Array(state.layouts.enumerated()), id: \.element.id) { i, layout in
                tile(layout: layout, index: i, geometry: geometry)
            }
        }
        .frame(width: geometry.panelSize.width, height: geometry.panelSize.height)
        .glassBackground(cornerRadius: 18)
    }

    private func tile(layout: SnapLayout, index: Int, geometry: PickerGeometry) -> some View {
        let tileRect = geometry.tileFrame(index: index)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .frame(width: tileRect.width, height: tileRect.height)
            ForEach(Array(layout.cells.enumerated()), id: \.offset) { j, cell in
                let cellRect = geometry.cellFrame(tileIndex: index, cell: cell)
                let isHovered = state.hover == PickerTarget(layoutIndex: index, cellIndex: j)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color.accentColor : Color.primary.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.primary.opacity(isHovered ? 0 : 0.12), lineWidth: 1)
                    )
                    .frame(width: cellRect.width, height: cellRect.height)
                    .offset(x: cellRect.minX - tileRect.minX, y: cellRect.minY - tileRect.minY)
                    .animation(.easeOut(duration: 0.1), value: state.hover)
            }
        }
        .offset(x: tileRect.minX, y: tileRect.minY)
    }
}

/// Owns the flyout panel: shows it near the top-center of a screen, tracks
/// hover from global cursor coordinates, and reports the drop target.
final class LayoutPickerController {
    private let panel = OverlayPanel(level: .statusBar, acceptsMouse: false)
    private let state = PickerState()
    private var geometry = PickerGeometry(layoutCount: 0)
    private(set) var isVisible = false
    /// Panel frame in CG coordinates, for keep-open hit testing.
    private(set) var panelFrameCG: CGRect = .zero

    init() {
        panel.setContent(LayoutPickerView(state: state))
    }

    /// Shows the flyout horizontally centered on `centerX`, with its top at
    /// `top` (CG coordinates), clamped to the screen.
    func show(layouts: [SnapLayout], screenFrame: CGRect, centerX: CGFloat, top: CGFloat) {
        state.layouts = layouts
        state.hover = nil
        geometry = PickerGeometry(layoutCount: layouts.count)
        let size = geometry.panelSize

        var frame = CGRect(
            x: centerX - size.width / 2,
            y: top,
            width: size.width,
            height: size.height
        )
        frame.origin.x = min(max(frame.origin.x, screenFrame.minX + 8), screenFrame.maxX - size.width - 8)
        frame.origin.y = min(max(frame.origin.y, screenFrame.minY + 8), screenFrame.maxY - size.height - 8)

        panelFrameCG = frame
        panel.setFrameCG(frame)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
        isVisible = true
    }

    /// Updates the highlighted cell from a cursor location in CG coordinates.
    func updateHover(cursor: CGPoint) {
        guard isVisible else { return }
        let local = CGPoint(x: cursor.x - panelFrameCG.minX, y: cursor.y - panelFrameCG.minY)
        let target = geometry.hitTest(local, layouts: state.layouts)
        if state.hover != target {
            state.hover = target
        }
    }

    /// The layout cell currently under the cursor, if any.
    var currentTarget: (layout: SnapLayout, cellIndex: Int)? {
        guard let hover = state.hover, hover.layoutIndex < state.layouts.count else { return nil }
        return (state.layouts[hover.layoutIndex], hover.cellIndex)
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        panel.orderOut(nil)
        state.hover = nil
    }
}

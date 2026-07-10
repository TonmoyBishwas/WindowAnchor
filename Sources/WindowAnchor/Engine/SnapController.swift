import AppKit

/// Orchestrates the snapping experience: receives drag events, decides when to
/// show the flyout / edge previews, and applies snaps on drop.
final class SnapController: DragMonitorDelegate {
    private let preferences: Preferences
    private let dragMonitor = DragMonitor()
    private let picker = LayoutPickerController()
    private let preview = SnapPreviewController()
    private let snapAssist = SnapAssistController()

    private var draggedWindow: AXWindow?
    private var hotZoneEnteredAt: CFTimeInterval?
    private var flyoutShowTimer: Timer?
    private var lastLocation: CGPoint = .zero
    private var currentEdgeZone: EdgeZone?

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
        dragMonitor.delegate = self
    }

    func start() {
        dragMonitor.start()
    }

    func stop() {
        dragMonitor.stop()
        cleanupDragUI()
    }

    // MARK: DragMonitorDelegate

    func dragBegan(window: AXWindow, at location: CGPoint) {
        guard preferences.snappingEnabled else { return }
        draggedWindow = window
        snapAssist.dismiss()
    }

    func dragMoved(to location: CGPoint, optionDown: Bool) {
        guard preferences.snappingEnabled, draggedWindow != nil else { return }
        lastLocation = location
        guard let screen = Coords.screen(containingCGPoint: location) else { return }
        let screenFrame = Coords.frameCG(of: screen)
        let zone = EdgeZones.zone(at: location, screenFrame: screenFrame, preferences: preferences)
        currentEdgeZone = zone

        // --- Flyout lifecycle ---
        if picker.isVisible {
            let keepOpenRegion = picker.panelFrameCG
                .insetBy(dx: -60, dy: -60)
                .union(EdgeZones.flyoutHotZone(screenFrame: screenFrame))
            if keepOpenRegion.contains(location) {
                picker.updateHover(cursor: location)
                preview.hide()
                return
            }
            hideFlyout()
        }

        if zone == .flyout {
            if hotZoneEnteredAt == nil {
                hotZoneEnteredAt = CACurrentMediaTime()
                scheduleFlyout(on: screen, at: nil)
            } else if let entered = hotZoneEnteredAt,
                      CACurrentMediaTime() - entered >= preferences.hoverDelay {
                showFlyout(on: screen, at: nil)
            }
            preview.hide()
            return
        }
        hotZoneEnteredAt = nil
        flyoutShowTimer?.invalidate()
        flyoutShowTimer = nil

        if optionDown, preferences.optionSummonsFlyout, !picker.isVisible {
            showFlyout(on: screen, at: location)
            return
        }

        // --- Edge previews ---
        if let cell = zone?.cell {
            let target = SnapEngine.frame(for: cell, in: Coords.visibleFrameCG(of: screen),
                                          gap: preferences.windowGap,
                                          outerPadding: preferences.outerPadding)
            preview.show(frameCG: target)
        } else {
            preview.hide()
        }
    }

    func dragEnded(at location: CGPoint) {
        defer {
            draggedWindow = nil
            cleanupDragUI()
        }
        guard preferences.snappingEnabled, let window = draggedWindow,
              let screen = Coords.screen(containingCGPoint: location) else { return }

        if picker.isVisible, let target = picker.currentTarget {
            let cell = target.layout.cells[target.cellIndex]
            SnapEngine.snap(window: window, cell: cell, on: screen, preferences: preferences)
            var remaining = target.layout.cells
            remaining.remove(at: target.cellIndex)
            snapAssist.begin(remainingCells: remaining, snappedWindow: window,
                             on: screen, preferences: preferences)
            return
        }

        if let zone = currentEdgeZone, zone != .flyout, let cell = zone.cell {
            SnapEngine.snap(window: window, cell: cell, on: screen, preferences: preferences)
            // Offer to fill the other half, Windows-style.
            if zone == .leftHalf || zone == .rightHalf {
                let other = zone == .leftHalf
                    ? LayoutCell(x: 0.5, y: 0, w: 0.5, h: 1)
                    : LayoutCell(x: 0, y: 0, w: 0.5, h: 1)
                snapAssist.begin(remainingCells: [other], snappedWindow: window,
                                 on: screen, preferences: preferences)
            }
        }
    }

    // MARK: Flyout helpers

    private func scheduleFlyout(on screen: NSScreen, at cursor: CGPoint?) {
        flyoutShowTimer?.invalidate()
        flyoutShowTimer = Timer.scheduledTimer(withTimeInterval: preferences.hoverDelay,
                                               repeats: false) { [weak self] _ in
            guard let self, self.draggedWindow != nil, self.hotZoneEnteredAt != nil else { return }
            self.showFlyout(on: screen, at: cursor)
        }
    }

    private func showFlyout(on screen: NSScreen, at cursor: CGPoint?) {
        guard !picker.isVisible else { return }
        let layouts = preferences.enabledLayouts
        guard !layouts.isEmpty else { return }
        let screenFrame = Coords.frameCG(of: screen)
        let visible = Coords.visibleFrameCG(of: screen)
        let centerX = cursor?.x ?? screenFrame.midX
        let top = cursor.map { $0.y + 14 } ?? (visible.minY + 8)
        picker.show(layouts: layouts, screenFrame: screenFrame, centerX: centerX, top: top)
        picker.updateHover(cursor: lastLocation)
    }

    private func hideFlyout() {
        picker.hide()
        hotZoneEnteredAt = nil
        flyoutShowTimer?.invalidate()
        flyoutShowTimer = nil
    }

    private func cleanupDragUI() {
        hideFlyout()
        preview.hide()
        currentEdgeZone = nil
    }
}

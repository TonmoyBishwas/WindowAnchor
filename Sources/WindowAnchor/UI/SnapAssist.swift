import AppKit
import SwiftUI

final class SnapAssistState: ObservableObject {
    @Published var candidates: [WindowInfo] = []
    var onPick: ((WindowInfo) -> Void)?
    var onDismiss: (() -> Void)?
}

/// Windows-11-style Snap Assist: after snapping a window, the next empty cell
/// shows the user's other windows; clicking one snaps it there.
struct SnapAssistView: View {
    @ObservedObject var state: SnapAssistState

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)]

    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(state.candidates) { candidate in
                        Button {
                            state.onPick?(candidate)
                        } label: {
                            VStack(spacing: 8) {
                                Image(nsImage: candidate.appIcon ?? NSImage())
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                Text(candidate.title.isEmpty ? candidate.appName : candidate.title)
                                    .font(.callout)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.primary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 110)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
            Button("Skip") { state.onDismiss?() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassBackground(cornerRadius: 16)
        .padding(6)
    }
}

/// Drives the Snap Assist flow across the remaining empty cells of a layout.
final class SnapAssistController {
    private let panel = OverlayPanel(level: .floating, acceptsMouse: true)
    private let state = SnapAssistState()
    private var remainingCells: [LayoutCell] = []
    private var screen: NSScreen?
    private var preferences: Preferences?
    private var dismissMonitor: Any?
    private(set) var isActive = false

    init() {
        state.onPick = { [weak self] info in self?.pick(info) }
        state.onDismiss = { [weak self] in self?.dismiss() }
        panel.setContent(SnapAssistView(state: state))
    }

    /// Starts Snap Assist for the cells left empty after a snap.
    func begin(remainingCells: [LayoutCell], snappedWindow: AXWindow,
               on screen: NSScreen, preferences: Preferences) {
        guard preferences.snapAssistEnabled, !remainingCells.isEmpty else { return }
        let candidates = WindowInfo.snapAssistCandidates(excluding: snappedWindow)
        guard !candidates.isEmpty else { return }

        self.remainingCells = remainingCells
        self.screen = screen
        self.preferences = preferences
        state.candidates = candidates
        isActive = true
        showPanelInNextCell()
        installDismissMonitor()
    }

    private func showPanelInNextCell() {
        guard let screen, let preferences, let cell = remainingCells.first else {
            dismiss()
            return
        }
        let frame = SnapEngine.frame(for: cell, in: Coords.visibleFrameCG(of: screen),
                                     gap: preferences.windowGap, outerPadding: preferences.outerPadding)
        panel.setFrameCG(frame)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    private func pick(_ info: WindowInfo) {
        guard let screen, let preferences, let cell = remainingCells.first else {
            dismiss()
            return
        }
        if let window = info.axWindow() {
            SnapEngine.snap(window: window, cell: cell, on: screen, preferences: preferences)
            window.raise()
        }
        remainingCells.removeFirst()
        state.candidates.removeAll { $0.id == info.id }
        if remainingCells.isEmpty || state.candidates.isEmpty {
            dismiss()
        } else {
            showPanelInNextCell()
        }
    }

    func dismiss() {
        guard isActive else { return }
        isActive = false
        panel.orderOut(nil)
        remainingCells = []
        state.candidates = []
        if let monitor = dismissMonitor {
            NSEvent.removeMonitor(monitor)
            dismissMonitor = nil
        }
    }

    /// Dismiss when the user clicks anywhere outside the panel or presses Esc.
    private func installDismissMonitor() {
        if let monitor = dismissMonitor { NSEvent.removeMonitor(monitor) }
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { [weak self] event in
            guard let self, self.isActive else { return }
            if event.type == .keyDown {
                if event.keyCode == 53 { self.dismiss() } // Esc
                return
            }
            // Global monitors report clicks in other apps; clicks on our own
            // panel arrive as local events and are not seen here.
            self.dismiss()
        }
    }
}

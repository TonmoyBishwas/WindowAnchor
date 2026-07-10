import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var snapController: SnapController?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController { [weak self] in
            self?.showSettings()
        }

        if Permissions.isTrusted {
            startSnapping()
        } else {
            Permissions.request()
            Permissions.waitUntilTrusted { [weak self] in
                self?.startSnapping()
            }
            // First launch: open Settings so the user sees what to do.
            showSettings()
        }
    }

    private func startSnapping() {
        guard snapController == nil else { return }
        let controller = SnapController()
        controller.start()
        snapController = controller
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "WindowAnchor Settings"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

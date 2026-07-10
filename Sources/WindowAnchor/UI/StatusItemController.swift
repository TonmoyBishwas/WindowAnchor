import AppKit

/// The menu bar presence: status icon, quick toggles, and entry points to
/// Settings and the Accessibility permission flow.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let preferences: Preferences
    private let openSettings: () -> Void

    init(preferences: Preferences = .shared, openSettings: @escaping () -> Void) {
        self.preferences = preferences
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.split.2x2",
                                accessibilityDescription: "WindowAnchor")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let title = NSMenuItem(title: "WindowAnchor", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        if !Permissions.isTrusted {
            let warning = NSMenuItem(title: "⚠️ Grant Accessibility Access…",
                                     action: #selector(grantAccess), keyEquivalent: "")
            warning.target = self
            menu.addItem(warning)
            menu.addItem(.separator())
        }

        let toggle = NSMenuItem(title: "Enable Snapping",
                                action: #selector(toggleSnapping), keyEquivalent: "")
        toggle.target = self
        toggle.state = preferences.snappingEnabled ? .on : .off
        menu.addItem(toggle)

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let github = NSMenuItem(title: "WindowAnchor on GitHub",
                                action: #selector(openGitHub), keyEquivalent: "")
        github.target = self
        menu.addItem(github)

        let quit = NSMenuItem(title: "Quit WindowAnchor", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleSnapping() {
        preferences.snappingEnabled.toggle()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func grantAccess() {
        Permissions.request()
        Permissions.openSystemSettings()
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/TonmoyBishwas/WindowAnchor")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

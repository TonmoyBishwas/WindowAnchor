import AppKit
import ApplicationServices

/// Accessibility permission flow. WindowAnchor cannot move windows or observe
/// drags until the user grants Accessibility access in System Settings.
final class Permissions {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt directing the user to System Settings.
    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Polls until access is granted, then calls `onGranted` once (on main).
    static func waitUntilTrusted(onGranted: @escaping () -> Void) {
        if isTrusted {
            onGranted()
            return
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if isTrusted {
                timer.invalidate()
                DispatchQueue.main.async(execute: onGranted)
            }
        }
    }
}

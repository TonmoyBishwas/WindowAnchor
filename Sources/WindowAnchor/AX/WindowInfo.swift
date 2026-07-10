import AppKit

/// A lightweight description of an on-screen window, used to build the
/// Snap Assist candidate list without extra permissions.
struct WindowInfo: Identifiable {
    let id: CGWindowID
    let pid: pid_t
    let title: String
    let appName: String
    let frame: CGRect   // CG coordinates
    let appIcon: NSImage?

    /// On-screen, normal-level windows of other apps, front-to-back.
    static func snapAssistCandidates(excluding excluded: AXWindow?) -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        let ownPid = ProcessInfo.processInfo.processIdentifier
        let excludedFrame = excluded?.frame
        let excludedPid = excluded?.pid

        var results: [WindowInfo] = []
        for entry in list {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPid,
                  let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            let frame = CGRect(x: boundsDict["X"] ?? 0, y: boundsDict["Y"] ?? 0,
                               width: boundsDict["Width"] ?? 0, height: boundsDict["Height"] ?? 0)
            // Skip tiny windows (palettes, hidden helpers).
            guard frame.width >= 200, frame.height >= 150 else { continue }

            // Skip the window that was just snapped.
            if let excludedFrame, let excludedPid, pid == excludedPid,
               abs(frame.minX - excludedFrame.minX) < 2, abs(frame.minY - excludedFrame.minY) < 2 {
                continue
            }

            let title = entry[kCGWindowName as String] as? String ?? ""
            let app = NSRunningApplication(processIdentifier: pid)
            results.append(WindowInfo(
                id: windowID,
                pid: pid,
                title: title,
                appName: app?.localizedName ?? entry[kCGWindowOwnerName as String] as? String ?? "App",
                frame: frame,
                appIcon: app?.icon
            ))
        }
        return results
    }

    /// Finds the matching AX window so it can be moved. Matches by title
    /// first, then by frame proximity.
    func axWindow() -> AXWindow? {
        let windows = AXWindow.windows(ofPid: pid)
        if !title.isEmpty, let byTitle = windows.first(where: { $0.title == title }) {
            return byTitle
        }
        return windows.min { a, b in
            distance(of: a) < distance(of: b)
        }
    }

    private func distance(of window: AXWindow) -> CGFloat {
        guard let f = window.frame else { return .greatestFiniteMagnitude }
        return abs(f.minX - frame.minX) + abs(f.minY - frame.minY)
            + abs(f.width - frame.width) + abs(f.height - frame.height)
    }
}

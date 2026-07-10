import Combine
import Foundation
import ServiceManagement

/// App settings, persisted to UserDefaults. Layouts are stored as JSON.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let layouts = "layouts.v1"
        static let snappingEnabled = "snappingEnabled"
        static let edgeSnapEnabled = "edgeSnapEnabled"
        static let cornerSnapEnabled = "cornerSnapEnabled"
        static let topEdgeMaximizes = "topEdgeMaximizes"
        static let layoutFlyoutEnabled = "layoutFlyoutEnabled"
        static let optionSummonsFlyout = "optionSummonsFlyout"
        static let snapAssistEnabled = "snapAssistEnabled"
        static let hoverDelay = "hoverDelay"
        static let windowGap = "windowGap"
        static let outerPadding = "outerPadding"
    }

    private let defaults: UserDefaults

    @Published var snappingEnabled: Bool { didSet { defaults.set(snappingEnabled, forKey: Key.snappingEnabled) } }
    @Published var edgeSnapEnabled: Bool { didSet { defaults.set(edgeSnapEnabled, forKey: Key.edgeSnapEnabled) } }
    @Published var cornerSnapEnabled: Bool { didSet { defaults.set(cornerSnapEnabled, forKey: Key.cornerSnapEnabled) } }
    @Published var topEdgeMaximizes: Bool { didSet { defaults.set(topEdgeMaximizes, forKey: Key.topEdgeMaximizes) } }
    @Published var layoutFlyoutEnabled: Bool { didSet { defaults.set(layoutFlyoutEnabled, forKey: Key.layoutFlyoutEnabled) } }
    @Published var optionSummonsFlyout: Bool { didSet { defaults.set(optionSummonsFlyout, forKey: Key.optionSummonsFlyout) } }
    @Published var snapAssistEnabled: Bool { didSet { defaults.set(snapAssistEnabled, forKey: Key.snapAssistEnabled) } }
    /// Seconds the cursor must hover in the hot zone before the flyout appears.
    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: Key.hoverDelay) } }
    /// Gap between snapped windows, in points.
    @Published var windowGap: Double { didSet { defaults.set(windowGap, forKey: Key.windowGap) } }
    /// Padding between snapped windows and the screen edge, in points.
    @Published var outerPadding: Double { didSet { defaults.set(outerPadding, forKey: Key.outerPadding) } }

    @Published var layouts: [SnapLayout] { didSet { saveLayouts() } }

    var enabledLayouts: [SnapLayout] { layouts.filter(\.isEnabled) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        func bool(_ key: String, default def: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? def : defaults.bool(forKey: key)
        }
        func double(_ key: String, default def: Double) -> Double {
            defaults.object(forKey: key) == nil ? def : defaults.double(forKey: key)
        }

        snappingEnabled = bool(Key.snappingEnabled, default: true)
        edgeSnapEnabled = bool(Key.edgeSnapEnabled, default: true)
        cornerSnapEnabled = bool(Key.cornerSnapEnabled, default: true)
        topEdgeMaximizes = bool(Key.topEdgeMaximizes, default: true)
        layoutFlyoutEnabled = bool(Key.layoutFlyoutEnabled, default: true)
        optionSummonsFlyout = bool(Key.optionSummonsFlyout, default: true)
        snapAssistEnabled = bool(Key.snapAssistEnabled, default: true)
        hoverDelay = double(Key.hoverDelay, default: 0.15)
        windowGap = double(Key.windowGap, default: 0)
        outerPadding = double(Key.outerPadding, default: 0)

        if let data = defaults.data(forKey: Key.layouts),
           let stored = try? JSONDecoder().decode([SnapLayout].self, from: data) {
            layouts = Self.merge(stored: stored)
        } else {
            layouts = SnapLayout.builtInPresets
        }
    }

    /// Keeps user ordering/enabled state and custom layouts, but re-adds any
    /// built-in presets introduced after the layouts were last saved.
    static func merge(stored: [SnapLayout]) -> [SnapLayout] {
        var result = stored
        // Refresh built-in cell definitions (in case presets change between versions).
        for (i, layout) in result.enumerated() {
            if let preset = SnapLayout.builtInPresets.first(where: { $0.id == layout.id }) {
                result[i].cells = preset.cells
                result[i].name = preset.name
                result[i].isBuiltIn = true
            }
        }
        let known = Set(result.map(\.id))
        result.append(contentsOf: SnapLayout.builtInPresets.filter { !known.contains($0.id) })
        return result
    }

    private func saveLayouts() {
        if let data = try? JSONEncoder().encode(layouts) {
            defaults.set(data, forKey: Key.layouts)
        }
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("WindowAnchor: launch-at-login change failed: \(error)")
            }
            objectWillChange.send()
        }
    }
}

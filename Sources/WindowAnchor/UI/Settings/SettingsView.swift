import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            LayoutsSettingsView()
                .tabItem { Label("Layouts", systemImage: "rectangle.split.2x2") }
            SnappingSettingsView()
                .tabItem { Label("Snapping", systemImage: "arrow.up.left.and.arrow.down.right") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 640, height: 520)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var accessibilityGranted = Permissions.isTrusted

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityGranted ? .green : .orange)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(accessibilityGranted ? "Accessibility access granted" : "Accessibility access required")
                            .fontWeight(.medium)
                        if !accessibilityGranted {
                            Text("WindowAnchor needs Accessibility access to move windows. Enable it in System Settings → Privacy & Security → Accessibility.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !accessibilityGranted {
                        Button("Open System Settings") {
                            Permissions.request()
                            Permissions.openSystemSettings()
                        }
                    }
                }
            }

            Section("Behavior") {
                Toggle("Enable window snapping", isOn: $prefs.snappingEnabled)
                Toggle("Show layout flyout when dragging to top-center", isOn: $prefs.layoutFlyoutEnabled)
                Toggle("Hold ⌥ Option while dragging to summon the flyout anywhere", isOn: $prefs.optionSummonsFlyout)
                Toggle("Snap Assist: suggest windows for the remaining space", isOn: $prefs.snapAssistEnabled)
                LabeledContent("Flyout hover delay") {
                    HStack {
                        Slider(value: $prefs.hoverDelay, in: 0...1)
                            .frame(width: 200)
                        Text(String(format: "%.2fs", prefs.hoverDelay))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch WindowAnchor at login", isOn: Binding(
                    get: { prefs.launchAtLogin },
                    set: { prefs.launchAtLogin = $0 }
                ))
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in
            accessibilityGranted = Permissions.isTrusted
        }
    }
}

// MARK: - Snapping

struct SnappingSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section("Edges & Corners") {
                Toggle("Drag to left/right edge snaps to half", isOn: $prefs.edgeSnapEnabled)
                Toggle("Drag to a corner snaps to quarter", isOn: $prefs.cornerSnapEnabled)
                Toggle("Drag to top edge maximizes", isOn: $prefs.topEdgeMaximizes)
            }

            Section("Spacing") {
                LabeledContent("Gap between windows") {
                    HStack {
                        Slider(value: $prefs.windowGap, in: 0...32, step: 1)
                            .frame(width: 200)
                        Text("\(Int(prefs.windowGap)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                LabeledContent("Padding from screen edges") {
                    HStack {
                        Slider(value: $prefs.outerPadding, in: 0...32, step: 1)
                            .frame(width: 200)
                        Text("\(Int(prefs.outerPadding)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.split.2x2.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("WindowAnchor")
                .font(.largeTitle.bold())
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                .foregroundStyle(.secondary)
            Text("Windows 11 style snap layouts for macOS.\nFree and open source.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("github.com/TonmoyBishwas/WindowAnchor",
                 destination: URL(string: "https://github.com/TonmoyBishwas/WindowAnchor")!)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

# CLAUDE.md — Agent Guide for WindowAnchor

WindowAnchor is a free, open-source macOS menu bar app that replicates **Windows 11
Snap Layouts**: drag a window to the top-center of the screen and a flyout of layout
presets appears; drop the window into a zone to snap it there. It targets people
switching from Windows to macOS. Swift + AppKit/SwiftUI, no dependencies, Apple
Silicon only.

**Read [CODEBASE.md](CODEBASE.md) before touching the engine or UI code.** It explains
the architecture, the drag-to-snap data flow, and the coordinate-system rules at the
ground level. This file covers commands, hard rules, and pitfalls.

## Commands

```bash
swift build                      # debug build
swift test                       # unit tests (geometry/tree/zone logic — no UI)
Scripts/build_app.sh 1.2.3       # release build → dist/WindowAnchor.app + dist/WindowAnchor-1.2.3.dmg
swift run WindowAnchor           # run from terminal (needs Accessibility permission for the terminal app)
```

Release flow (see [docs/RELEASING.md](docs/RELEASING.md) for the full checklist):

```bash
Scripts/build_app.sh <version>
gh release create v<version> dist/WindowAnchor-<version>.dmg --title "WindowAnchor <version>" --notes "..."
```

## Hard rules — things that must stay as they are

1. **The event tap stays `.listenOnly`** (`DragMonitor.swift`). Making it an active
   tap would add input latency to every mouse event system-wide and change the app's
   security posture. All snapping decisions are made from observed events only.

2. **`PickerGeometry` is the single source of truth for flyout metrics**
   (`UI/LayoutPicker.swift`). The user is mid-drag when the flyout is open, so the
   panel **never receives real mouse events** — hover highlighting is computed by
   hit-testing global cursor coordinates against `PickerGeometry` math. If you change
   the flyout's visual layout, you MUST change it through `PickerGeometry` constants so
   the SwiftUI rendering and the hit-testing stay in sync. Never hardcode tile/padding
   numbers in the view.

3. **Built-in preset UUIDs are frozen** (`Model/SnapLayout.swift`, the
   `9A1DE7F0-000N-...` IDs). `Preferences.merge(stored:)` matches stored layouts to
   presets by ID to preserve user ordering/enabled state across updates. Changing an ID
   duplicates the preset for every existing user. New presets get a new stable UUID in
   the same style; removed presets keep their ID retired forever.

4. **Persisted formats are compatibility surfaces.** User layouts are stored in
   UserDefaults under `"layouts.v1"` as JSON (`SnapLayout` + the custom `SplitNode`
   coding: `kind`/`axis`/`ratio`/`first`/`second`). Any breaking change requires a new
   key (`layouts.v2`) plus a migration from v1 — never silently change the shape.

5. **CG coordinates (top-left origin, y down) are the internal standard.** Event tap,
   AX API, zones, and engine math all use CG space. Convert to AppKit (bottom-left
   origin) only at the last moment when placing NSPanels, and only via the `Coords`
   helper (`Support/CoordinateSpace.swift`). Never mix spaces or hand-roll conversions.

6. **`swift-tools-version: 5.10` is deliberate.** Swift 6 strict concurrency rejects
   the C-callback patterns in `DragMonitor` (CGEventTap refcon round-tripping). Bumping
   the tools version requires reworking that code first; don't bump it casually.

7. **Ad-hoc signing is the distribution model** (no paid Apple Developer ID). The
   README and every release's notes MUST keep the Gatekeeper workaround instructions
   (right-click → Open, and `xattr -cr /Applications/WindowAnchor.app`). Removing them
   strands new users at the "app is damaged" dialog.

8. **`AXWindow.setFrame` sets position → size → position on purpose.** Many apps clamp
   one attribute against the other; the double-set makes snapping stick. Don't
   "simplify" it to a single position+size write.

9. **The app is `LSUIElement` with `.accessory` activation policy** — menu bar only,
   no Dock icon. UI panels are non-activating `OverlayPanel`s so snapping never steals
   focus from the dragged app.

## Common mistakes to avoid

- **Testing interactive behavior without permission.** Drag/snap only works when the
  built `.app` has Accessibility permission. `swift test` covers pure logic only; a
  passing test suite does NOT mean the drag flow works. After code changes, rebuild
  with `Scripts/build_app.sh`, launch the app, and drag real windows. Note: each
  rebuild produces a new ad-hoc signature — macOS may require toggling the
  Accessibility checkbox off/on for the new binary.
- **Complex inline SwiftUI expressions.** The compiler has already hit
  "unable to type-check this expression in reasonable time" in layout-thumbnail code
  mixing `Double` cell fields with `CGFloat` sizes. Pre-compute `CGRect`s/values in
  `let` bindings before applying view modifiers (see `LayoutsSettingsView.swift`).
- **Forgetting the second coordinate flip.** `NSScreen` frames are AppKit-space;
  event-tap points are CG-space. Symptom of mixing them: overlays appear on the wrong
  half of the screen or on the wrong display. Always go through `Coords`.
- **Blocking the event-tap callback.** `DragMonitor.handle` runs for every mouse event
  during a drag. Keep it cheap; AX frame reads are already throttled to one per 50 ms —
  keep that throttle.
- **Reading prefs from `UserDefaults` directly.** Always go through
  `Preferences.shared` (it owns defaults, publishes changes, and merges layouts).
  Tests may construct `Preferences(defaults:)` with an isolated suite.
- **Committing `dist/` or generated icons.** `dist/`, `.build/` are gitignored;
  the icon is generated at build time by `Scripts/make_icon.swift`.

## Testing expectations

- Run `swift test` after every engine/model change. Tests live in
  `Tests/WindowAnchorTests/WindowAnchorTests.swift` (SnapEngine gaps/padding, SplitNode
  editing + Codable, EdgeZones classification, Preferences.merge, PickerGeometry hit
  tests). New pure-logic code gets tests in the same style — isolated
  `UserDefaults(suiteName:)` when preferences are involved.
- Manual smoke test before any release: flyout appears on top-center hover, drop snaps,
  Snap Assist offers remaining windows, edge/corner previews work, Settings opens.

## Repo pointers

| Where | What |
| --- | --- |
| `CODEBASE.md` | Ground-level architecture and file-by-file tour — start here |
| `CONTRIBUTING.md` | Human contributor workflow, style, PR expectations |
| `docs/RELEASING.md` | Step-by-step release checklist |
| `docs/superpowers/specs/2026-07-10-windowanchor-design.md` | Original v1 design doc (rationale for the big decisions) |
| GitHub | https://github.com/TonmoyBishwas/WindowAnchor (releases carry the DMG) |

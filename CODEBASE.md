# CODEBASE.md — Ground-Level Tour of WindowAnchor

This document explains how WindowAnchor works from the ground up: the architecture,
the exact data flow of a drag-to-snap gesture, the coordinate-system rules, every
source file's job, and the design decisions behind them. If you are new to this
codebase (human or AI), read this once before changing anything.

Companion docs: [CLAUDE.md](CLAUDE.md) (hard rules & commands),
[CONTRIBUTING.md](CONTRIBUTING.md) (workflow), [docs/RELEASING.md](docs/RELEASING.md)
(shipping).

---

## 1. What the app is, mechanically

A menu-bar-only (`LSUIElement`) AppKit app with no dependencies. It:

1. Watches global mouse events through a **listen-only CGEventTap** to notice when the
   user drags a window.
2. Shows borderless, **non-activating overlay panels** (the layout flyout, a snap
   preview rectangle, the Snap Assist picker) while the drag is in progress.
3. Moves/resizes windows of *other* apps through the **macOS Accessibility (AX) API**
   when the user drops.

It requires the Accessibility permission (`AXIsProcessTrusted`) and nothing else. No
screen recording, no network, no private APIs.

## 2. Directory layout

```
Sources/WindowAnchor/
├── main.swift                    # entry point: NSApplication + .accessory policy
├── AppDelegate.swift             # launch sequence, permission flow, Settings window
├── Permissions.swift             # AXIsProcessTrusted helpers + polling
├── AX/
│   ├── AXWindow.swift            # wrapper over AXUIElement: find/read/move windows
│   └── WindowInfo.swift          # CGWindowList census for Snap Assist candidates
├── Engine/
│   ├── DragMonitor.swift         # CGEventTap; detects "user is dragging a window"
│   ├── EdgeZones.swift           # classifies cursor position → snap zone
│   ├── SnapEngine.swift          # normalized cell → pixel frame math (gaps/padding)
│   └── SnapController.swift      # orchestrator wiring all of the above to the UI
├── Model/
│   ├── SnapLayout.swift          # LayoutCell, SplitNode (BSP tree), built-in presets
│   ├── SplitNodeEditing.swift    # split/delete/ratio ops for the layout editor
│   └── Preferences.swift         # settings singleton, UserDefaults persistence
├── Support/
│   └── CoordinateSpace.swift     # Coords: CG ↔ AppKit conversions, screen lookup
└── UI/
    ├── OverlayPanel.swift        # non-activating borderless NSPanel base
    ├── Glass.swift               # .glassBackground() — Liquid Glass w/ fallback
    ├── LayoutPicker.swift        # the flyout: PickerGeometry + view + controller
    ├── SnapPreview.swift         # translucent drop-target preview rectangle
    ├── SnapAssist.swift          # post-snap "fill the other zones" picker
    ├── StatusItemController.swift# menu bar item + menu
    └── Settings/
        ├── SettingsView.swift        # TabView: General / Layouts / Snapping / About
        ├── LayoutsSettingsView.swift # layout list, reorder, thumbnails
        └── LayoutEditorView.swift    # visual BSP editor for custom layouts

Tests/WindowAnchorTests/WindowAnchorTests.swift   # 20 pure-logic tests
Packaging/Info.plist              # template; APP_VERSION/APP_BUILD sed-replaced
Scripts/build_app.sh              # release build → .app → ad-hoc sign → DMG
Scripts/make_icon.swift           # draws AppIcon.icns at build time
```

## 3. Coordinate systems (the #1 source of bugs)

Two coordinate spaces exist on macOS:

- **CG / global display space** — origin at **top-left** of the primary display,
  y grows **down**. Used by: CGEventTap locations, the AX API, `CGWindowList`.
- **AppKit space** — origin at **bottom-left** of the primary display, y grows **up**.
  Used by: `NSScreen.frame`, `NSWindow`/`NSPanel` placement.

**Rule: everything internal is CG space.** Zones, engine math, panel frames tracked
for hit-testing (`panelFrameCG`), delegate callbacks — all CG. The only conversions
happen inside `Support/CoordinateSpace.swift` (`Coords`):

- `Coords.cgToAppKit(rect:)` / `appKitToCG(...)` — flip using the **primary** screen's
  height (both spaces are global; the flip is always against the primary screen).
- `Coords.screen(containingCGPoint:)` — find the NSScreen under a CG point.
- `Coords.frameCG(of:)` / `visibleFrameCG(of:)` — a screen's (visible) frame in CG.

`OverlayPanel.setFrameCG(_:)` is the one place UI code crosses the boundary.

## 4. The drag-to-snap data flow, step by step

**Wiring** (at launch, `AppDelegate`): if `Permissions.isTrusted`, a `SnapController`
is created and `start()`ed; it owns a `DragMonitor` (events in), a
`LayoutPickerController` (flyout), a `SnapPreviewController` (edge preview), and a
`SnapAssistController` (post-snap fill).

1. **Mouse down** — `DragMonitor.beginGesture`: `AXWindow.at(point:)` asks the AX API
   what window is under the cursor (walks up to `kAXWindowRole`, falls back to the
   element's `kAXWindowAttribute`). Skips our own pid and non-standard windows. The
   window and its starting frame become the *candidate*.
2. **Drag confirmation** — `DragMonitor.continueGesture`: nothing happens until the
   mouse has moved > 8 px. Then, at most once per 50 ms (AX reads are expensive), the
   candidate's current AX frame is compared to its start frame. If the window moved
   > 4 px and its delta matches the mouse delta within 100 px on each axis, the user is
   really dragging *the window* (not selecting text or scrubbing a slider) →
   `dragConfirmed`, delegate gets `dragBegan` + `dragMoved`. This heuristic is how we
   detect window drags without private APIs.
3. **During the drag** — `SnapController.dragMoved` (every mouse move, CG coords):
   - `EdgeZones.zone(at:screenFrame:preferences:)` classifies the cursor:
     `.flyout` (top-center hot zone, 420×12 px), quarters (vertical edge within 140 px
     of top/bottom), halves (left/right edge, 8 px threshold), `.maximize` (top edge).
     Priority: flyout → corners → edges → maximize. Each category is gated by its
     preference toggle.
   - **Flyout lifecycle**: entering `.flyout` starts a `hoverDelay` timer (default
     0.15 s); when it fires (or elapsed time passes on a later move event), the flyout
     is shown top-center. While visible, the cursor is hit-tested against a *keep-open
     region* (panel frame inset by −60 px, unioned with the hot zone); inside it,
     `picker.updateHover(cursor:)` runs; leaving it hides the flyout.
   - **Option key** (⌥ held, read from event flags): summons the flyout at the cursor.
   - Otherwise, an edge zone's cell is converted to a pixel frame by `SnapEngine` and
     shown as a translucent `SnapPreview`.
4. **Hover highlighting inside the flyout** — critical subtlety: while the user drags,
   **the OS routes all mouse events to the dragged app's window**, so our panel never
   gets mouseEntered/mouseMoved. Instead, `LayoutPickerController.updateHover`
   translates the global cursor into panel-local coordinates and calls
   `PickerGeometry.hitTest`, pure math over fixed constants (3 columns, 128×80 tiles,
   10 spacing, 14 padding, 3 cell inset). The SwiftUI view renders from the *same*
   constants. **They must never diverge** — that's why there are no magic numbers in
   `LayoutPickerView`.
5. **Mouse up** — `SnapController.dragEnded`:
   - Flyout visible + a cell hovered → `SnapEngine.snap` the window into that cell,
     then start **Snap Assist** with the layout's remaining cells.
   - Otherwise an active edge zone → snap to its cell; for plain halves, Snap Assist
     offers the complementary half (Windows behavior).
   - Either way all overlay UI is torn down.
6. **Snap math** — `SnapEngine.frame(for:in:gap:outerPadding:)`: the screen's visible
   frame (CG) is inset by `outerPadding`; each cell edge that is *interior* (not at
   0 or 1, epsilon 0.001) is inset by `gap/2` so neighbors share the gap evenly;
   result is `.integral`. `SnapEngine.snap` then calls `AXWindow.setFrame`, which
   writes **position → size → position** because many apps clamp one attribute against
   the other.
7. **Snap Assist** — `SnapAssistController.begin`: lists other windows via
   `CGWindowListCopyWindowInfo` (on-screen, layer 0, ≥ 200×150, excluding our pid and
   the just-snapped window, matched by pid + origin within 2 px). The picker panel is
   placed **over the next empty cell's frame** and shows app icon + title per
   candidate. Clicking one resolves its `AXWindow` (match by title, else nearest
   frame), snaps + raises it, and advances to the next empty cell. Esc (keyCode 53) or
   clicking outside dismisses (global NSEvent monitors — these DO work here because the
   user is no longer dragging).

## 5. The layout model

- **`LayoutCell`** — normalized rect (0…1, top-left origin) inside a screen. This is
  the universal currency: presets, edge zones, the flyout, the engine, Snap Assist all
  speak `LayoutCell`.
- **`SnapLayout`** — id + name + `[LayoutCell]` + optional `tree` + `isEnabled` +
  `isBuiltIn`. The six built-in presets carry **frozen UUIDs** (`9A1DE7F0-000N-…`);
  `Preferences.merge(stored:)` uses them to refresh preset definitions on upgrade while
  preserving the user's order/enabled state and re-adding newly introduced presets.
- **`SplitNode`** — an indirect BSP enum (`leaf` | `split(axis:ratio:first:second)`).
  Custom layouts are edited as a tree (the editor can't produce overlaps or gaps by
  construction) and flattened to cells via `cells(in:)` (ratio clamped 0.05…0.95).
  Custom `Codable` keys (`kind`/`axis`/`ratio`/`first`/`second`) are a **persistence
  format** — see the compatibility rule in CLAUDE.md.
- **`SplitNodeEditing`** — editor operations addressed by **DFS leaf index** (the same
  order `cells()` emits, which is how the editor's numbered zones map to the tree):
  `splittingLeaf(at:axis:)` (50/50), `deletingLeaf(at:)` (sibling absorbs the region),
  `ancestorRatio(ofLeaf:)`/`settingAncestorRatio(ofLeaf:to:)` (nearest ancestor split).

## 6. Preferences

`Preferences.shared` (ObservableObject) is the only reader/writer of UserDefaults.
Every setting is a `@Published var` with a `didSet` persist. Defaults worth knowing:
everything enabled, `hoverDelay` 0.15 s, `windowGap` 0, `outerPadding` 0. Layouts
persist as JSON under the versioned key **`"layouts.v1"`**. `launchAtLogin` is not
stored — it proxies `SMAppService.mainApp` status directly. Tests construct
`Preferences(defaults: UserDefaults(suiteName: ...))` for isolation.

## 7. The UI machinery

- **`OverlayPanel`** — the base for all overlays: borderless + `.nonactivatingPanel`,
  `.floating`/`.statusBar` level, clear, non-opaque, `canBecomeKey/Main = false`,
  `.canJoinAllSpaces`, shown with `orderFrontRegardless()`. `acceptsMouse` controls
  `ignoresMouseEvents` (true only for Snap Assist, which appears *after* the drag).
  Content is SwiftUI via `NSHostingView` (`setContent`).
- **`Glass.swift`** — `.glassBackground(cornerRadius:)`: real
  `.glassEffect(.regular, in:)` behind `#available(macOS 26.0, *)`, otherwise
  `.ultraThinMaterial` + subtle white stroke. The app targets macOS 14; keep every
  macOS-26 API behind availability checks.
- **Settings** — an ordinary titled `NSWindow` (640×520, transparent titlebar) created
  lazily by `AppDelegate.showSettings`, hosting `SettingsView` (TabView). The General
  tab polls `Permissions.isTrusted` every 2 s so the status row updates live.
- **`StatusItemController`** — the menu bar item (`rectangle.split.2x2` SF Symbol,
  template so it adapts to menu bar appearance). The menu is rebuilt on open via
  `NSMenuDelegate`: permission warning (when untrusted), Enable Snapping toggle,
  Settings…, GitHub, Quit.

## 8. Launch & permission flow

`main.swift` builds `NSApplication`, sets `.accessory` policy (no Dock icon), attaches
`AppDelegate`. On launch: create the status item; if trusted → `startSnapping()`; if
not → `Permissions.request()` (system prompt), poll `waitUntilTrusted` every 1 s, then
start snapping and open Settings so the user sees the confirmed status.

Gotcha for anyone iterating locally: Accessibility permission is bound to the signed
binary. Rebuilding with a new ad-hoc signature can invalidate the grant — if drags stop
being detected after a rebuild, toggle WindowAnchor off/on in System Settings →
Privacy & Security → Accessibility.

## 9. Key constants (and where they live)

| Constant | Value | File |
| --- | --- | --- |
| Flyout hot zone | 420 × 12 px, top-center | `EdgeZones.flyoutZoneWidth/Height` |
| Edge threshold | 8 px | `EdgeZones.edgeThreshold` |
| Corner reach | 140 px along vertical edges | `EdgeZones.cornerReach` |
| Drag confirm: mouse | > 8 px moved | `DragMonitor.continueGesture` |
| Drag confirm: window | > 4 px, delta within 100 px of mouse | `DragMonitor.continueGesture` |
| AX frame sample rate | ≥ 50 ms apart | `DragMonitor.lastFrameCheck` |
| Flyout tiles | 3 cols, 128×80, spacing 10, padding 14 | `PickerGeometry` |
| Flyout keep-open slack | panel frame inset −60 px | `SnapController.dragMoved` |
| Hover delay default | 0.15 s (user-tunable 0–1 s) | `Preferences.hoverDelay` |
| Interior-edge epsilon | 0.001 | `SnapEngine.frame` |
| Snap Assist min window | 200 × 150 px | `WindowInfo` |

If you tune UX feel, these are the knobs. Consider whether a knob should become a
user-facing preference instead of a new magic number.

## 10. Tests

`swift test` runs 20 tests, all pure logic, no UI or AX:

- **SnapEngineTests** — full-cell frames, halves sharing a gap, outer padding,
  quarters non-overlap.
- **SplitNodeTests** — flattening, split/delete editing, ratio round-trip, Codable
  round-trip (guards the persistence format).
- **EdgeZoneTests** — zone classification for every zone + preference-disabled
  fallbacks, using an isolated `UserDefaults` suite.
- **PreferencesMergeTests** — preset refresh / re-add behavior.
- **PickerGeometry** hit-test cases.

What tests can never cover: event-tap behavior, AX moves against real apps, overlay
placement across multiple displays. Those need a built, permission-granted app and a
human dragging windows (see the manual checklist in CONTRIBUTING.md).

## 11. Build & packaging

`Scripts/build_app.sh <version>`:

1. `swift build -c release --arch arm64`
2. `swift Scripts/make_icon.swift dist` — draws the icon programmatically (gradient
   squircle + snap motif) and runs `iconutil` → `AppIcon.icns`. No binary icon assets
   in the repo.
3. Assembles `dist/WindowAnchor.app` by hand: binary from
   `.build/arm64-apple-macosx/release/`, `Packaging/Info.plist` with
   `APP_VERSION`/`APP_BUILD` placeholders sed-replaced.
4. `codesign --force --deep --sign -` (**ad-hoc**; see the Gatekeeper rule in
   CLAUDE.md).
5. `hdiutil` → `dist/WindowAnchor-<version>.dmg` with an `/Applications` symlink.

There is no Xcode project — SwiftPM only. `dist/` and `.build/` are gitignored.

## 12. Design decisions you should not re-litigate casually

- **Listen-only tap + AX-frame drag heuristic** instead of active event interception
  or private `CGSSetWindowMoving` APIs: zero input latency, App-Store-grade API usage,
  at the cost of a tiny confirmation delay. Chosen deliberately.
- **BSP tree for custom layouts** instead of freeform rects: the editor can't create
  overlapping or unreachable zones, and ratio edits stay valid by construction.
- **Fixed-metrics flyout** instead of adaptive sizing: hit-testing from global cursor
  coordinates requires geometry that is computable without asking the view.
- **SwiftPM + hand-assembled bundle** instead of an Xcode project: diffable,
  CI-friendly, no pbxproj merge conflicts.
- **macOS 14 floor, arm64 only**: matches the target audience (recent switchers on
  Apple Silicon) and keeps the glass UI path simple.

Future work candidates (explicit v1 non-goals, fine to add later): keyboard shortcuts
(Win+arrow style), live window thumbnails in Snap Assist, per-display layouts,
multi-display flyout tuning, localization, notarized builds (needs a paid Apple
Developer account), Sparkle/auto-update.

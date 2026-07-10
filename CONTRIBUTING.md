# Contributing to WindowAnchor

Thanks for helping build a free, open-source Windows-11-style window manager for
macOS! This guide covers everything from first build to pull request.

New to the code? Read [CODEBASE.md](CODEBASE.md) first — it explains the architecture
and the drag-to-snap flow end to end. [CLAUDE.md](CLAUDE.md) lists the hard invariants
(frozen preset UUIDs, coordinate rules, persistence formats); PRs that break those
will be asked to change.

## Prerequisites

- Apple Silicon Mac (M1 or newer)
- macOS 14 Sonoma or later
- Xcode 16+ (command line tools are enough — the project is pure SwiftPM, no
  `.xcodeproj`)

## Getting started

```bash
git clone https://github.com/TonmoyBishwas/WindowAnchor.git
cd WindowAnchor
swift build          # compile
swift test           # run the unit tests
```

To actually try your changes:

```bash
Scripts/build_app.sh 0.0.0-dev
open dist/WindowAnchor.app
```

Then grant Accessibility permission: System Settings → Privacy & Security →
Accessibility → enable WindowAnchor.

> **Permission gotcha:** the grant is tied to the binary's signature, and each build is
> ad-hoc signed. If drag detection stops working after a rebuild, toggle WindowAnchor
> off and on in the Accessibility list. Quit any old copy first (menu bar icon → Quit)
> so you're not testing a stale build.

## Testing your changes

**Unit tests** (`swift test`) cover the pure logic: snap-frame math, the BSP layout
tree, edge-zone classification, preferences merging, flyout hit-testing. If you touch
`Engine/` or `Model/`, add or update tests in
`Tests/WindowAnchorTests/WindowAnchorTests.swift`. Use an isolated
`UserDefaults(suiteName:)` when preferences are involved — never the standard suite.

**Manual checklist** — unit tests cannot exercise the event tap, the AX API, or
overlay placement, so run through this with the built app before opening a PR that
touches engine or UI code:

- [ ] Drag a window to the top-center → flyout appears after the hover delay
- [ ] Hovering flyout cells highlights them; dropping snaps the window there
- [ ] Snap Assist appears afterwards and fills the remaining zone(s) on click;
      Esc and clicking elsewhere dismiss it
- [ ] Hold ⌥ Option mid-drag → flyout appears at the cursor
- [ ] Drag to left/right edge → half preview; corners → quarter preview; top edge →
      maximize preview; dropping applies them
- [ ] Settings: toggles take effect immediately; a custom layout can be created in the
      editor and used from the flyout
- [ ] Works on a second display if you have one (different scale factors are the
      classic failure mode)
- [ ] Try a few stubborn apps (Terminal has size increments; some Electron apps clamp
      resizes)

## Code style

- Match the existing code. Four-space indent, `// MARK:` sections, doc comments (`///`)
  on types and non-obvious methods.
- Comments explain *why* or a constraint the code can't show — not what the next line
  does.
- All internal geometry is in CG coordinates (top-left origin). Convert to AppKit only
  through `Coords`. See CODEBASE.md §3.
- Keep SwiftUI expressions decomposed: pre-compute rects/values in `let` bindings
  before applying modifiers. The compiler has already hit type-check timeouts on this
  codebase from clever one-liners.
- No new dependencies without prior discussion in an issue — zero-dependency is a
  feature (small binary, no supply chain, easy audits).
- Keep `swift-tools-version` at 5.10 (see CLAUDE.md for why).

## Adding a built-in layout preset

1. Append a `SnapLayout` to `builtInPresets` in `Sources/WindowAnchor/Model/SnapLayout.swift`
   with a **new stable UUID** following the `9A1DE7F0-000N-4000-8000-00000000000N`
   pattern. Never reuse or change existing IDs.
2. Cells are normalized (0…1, top-left origin) and must tile the screen without
   overlaps or gaps.
3. `Preferences.merge` re-adds new presets to existing users automatically — no
   migration needed.
4. Add a test asserting the cells cover the unit square, mirroring the existing
   quarters test.

## Pull requests

- Open an issue first for anything beyond a small fix, so the approach can be agreed
  on before you invest time.
- Keep PRs focused — one behavior change per PR.
- Include: what changed, why, how you tested it (which manual-checklist items you ran).
- `swift test` must pass; a release build (`Scripts/build_app.sh`) must succeed.
- Update docs when behavior changes: README for user-facing features, CODEBASE.md for
  architecture/constants, CLAUDE.md if an invariant is added or removed.

## Reporting bugs

Please include: macOS version, Mac model, the app you were dragging (snapping bugs are
often app-specific — some apps clamp resizes), and steps to reproduce. Mention whether
Accessibility permission shows as granted in the app's Settings → General tab.

## Releases

Maintainers only — see [docs/RELEASING.md](docs/RELEASING.md).

## License

MIT. By contributing you agree your contributions are licensed under the same terms.

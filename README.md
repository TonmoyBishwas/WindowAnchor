# WindowAnchor

**Windows 11 style Snap Layouts for macOS.** Free, open source, Apple Silicon.

If you switched from Windows (or use both) and miss dragging a window to the top of the
screen to get that neat layout picker — this is it, on your Mac.

## What it does

- **Snap Layouts flyout** — while dragging any window, move the cursor to the
  **top-center of the screen**: a flyout appears with layout presets (halves, ⅔+⅓,
  thirds, half + stacked, quarters, center focus). Drop the window on a zone to snap it
  there. You can also hold **⌥ Option** while dragging to summon the flyout anywhere.
- **Snap Assist** — after you snap a window, your other open windows appear in the
  remaining empty zone. Click one to fill it, just like Windows 11.
- **Edge snapping** — drag to the left/right edge for half-screen, into a corner for a
  quarter, or to the top edge to maximize. A translucent preview shows where the window
  will land before you drop it.
- **Fully customizable** — enable/disable/reorder layouts, build your own layouts with a
  visual editor (split zones horizontally/vertically, adjust ratios), set gaps between
  windows and padding from screen edges, tune the flyout hover delay, launch at login.
- **Modern & minimal** — a menu bar app with a Liquid Glass look. No Dock icon, no
  clutter.

## Install (easy way)

1. Download **WindowAnchor-x.y.z.dmg** from the
   [latest release](https://github.com/TonmoyBishwas/WindowAnchor/releases/latest).
2. Open the DMG and drag **WindowAnchor** into **Applications**.
3. **First launch:** right-click (or Control-click) WindowAnchor in Applications and
   choose **Open**, then click **Open** in the dialog.
   > macOS shows a warning because this free app isn't notarized by Apple (that requires
   > a paid developer account). The right-click → Open dance is only needed once.
   > If macOS still refuses, run this once in Terminal:
   > `xattr -cr /Applications/WindowAnchor.app`
4. **Grant Accessibility access** when asked: System Settings → Privacy & Security →
   Accessibility → enable **WindowAnchor**. The app cannot move windows without this.
5. Drag any window to the top-center of your screen. Enjoy. 🎉

## Requirements

- Apple Silicon Mac (M1 or newer)
- macOS 14 Sonoma or later (native Liquid Glass styling on macOS 26+)

## Customization

Click the WindowAnchor icon in the menu bar → **Settings…**

| Tab | What you can change |
| --- | --- |
| General | Enable/disable snapping, flyout trigger options, Snap Assist, hover delay, launch at login |
| Layouts | Toggle/reorder the layout presets, create and edit your own layouts visually |
| Snapping | Edge/corner/top-edge snapping toggles, window gaps, screen edge padding |

## Build from source

```bash
git clone https://github.com/TonmoyBishwas/WindowAnchor.git
cd WindowAnchor
Scripts/build_app.sh 1.0.0     # → dist/WindowAnchor.app + dist/WindowAnchor-1.0.0.dmg
```

Requires Xcode 16+ command line tools. Run the unit tests with `swift test`.

## How it works

WindowAnchor uses the macOS Accessibility API to position windows and a listen-only
event tap to notice when you're dragging one. It never captures your screen, never
touches the network, and stores its settings locally. The full source is in this repo.

## License

[MIT](LICENSE) — free for everyone, forever.

# Releasing WindowAnchor

Step-by-step checklist for shipping a new version. The whole flow takes about ten
minutes and requires: push access to the repo, the `gh` CLI authenticated, and an
Apple Silicon Mac with Xcode 16+ command line tools.

## Versioning

Semantic-ish: `MAJOR.MINOR.PATCH`.

- **PATCH** — bug fixes, UX tuning (constants, delays), doc-only app changes
- **MINOR** — new user-facing features (new preset, new setting, keyboard shortcuts…)
- **MAJOR** — breaking changes to stored data or big behavioral overhauls

If you change the persisted layout format, remember the compatibility rule in
[CLAUDE.md](../CLAUDE.md): new UserDefaults key + migration, and that alone warrants
at least a MINOR bump.

## Checklist

1. **Green tests**

   ```bash
   swift test
   ```

2. **Build the release artifacts**

   ```bash
   Scripts/build_app.sh <version>          # e.g. Scripts/build_app.sh 1.1.0
   ```

   This produces `dist/WindowAnchor.app` and `dist/WindowAnchor-<version>.dmg`,
   ad-hoc signed. The script verifies the signature; also sanity-check the DMG:

   ```bash
   hdiutil verify dist/WindowAnchor-<version>.dmg
   ```

3. **Manual smoke test the built app** (not `swift run` — the actual bundle):
   open `dist/WindowAnchor.app`, re-grant Accessibility if needed (new signature),
   then run the manual checklist in [CONTRIBUTING.md](../CONTRIBUTING.md). At minimum:
   flyout appears → drop snaps → Snap Assist works → Settings opens → version on the
   About tab shows `<version>`.

4. **Commit and push** anything outstanding to `main`. The release tag should point at
   the code that built the DMG.

5. **Create the GitHub release**

   ```bash
   gh release create v<version> dist/WindowAnchor-<version>.dmg \
     --title "WindowAnchor <version>" \
     --notes "$(cat <<'EOF'
   ## What's new
   - ...

   ## Install
   Download the DMG, drag WindowAnchor to Applications.
   **First launch:** right-click the app → Open → Open. macOS warns because this free
   app is not notarized (that requires a paid Apple developer account). If it still
   refuses: `xattr -cr /Applications/WindowAnchor.app`
   Then grant Accessibility access when asked.
   EOF
   )"
   ```

   **The Install section with the Gatekeeper workaround is mandatory in every
   release's notes.** Builds are ad-hoc signed; without those instructions new users
   hit the "damaged / unidentified developer" dialog and give up.

6. **Verify the release page**: the DMG asset is attached and downloads, the tag
   matches, `releases/latest` resolves to it (the README install link depends on
   that).

## Notes for the future

- **Notarization**: if the project ever gets a paid Apple Developer ID, replace the
  ad-hoc `codesign` in `Scripts/build_app.sh` with a Developer ID certificate +
  `notarytool` submission + stapling, and then simplify the install instructions in
  README and the release-notes template above.
- **Auto-update**: there is no update mechanism; users reinstall from the DMG. If
  adding Sparkle or similar, that ends the zero-dependency policy — discuss in an
  issue first.
- **CI releases**: `swift build`/`swift test` run fine on GitHub's `macos-14+` arm64
  runners if release automation is ever wanted; the icon script and `hdiutil` work
  headless.

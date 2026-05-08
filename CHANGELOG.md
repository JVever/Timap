# Changelog

All notable changes to Timap are tracked here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.4] — 2026-05-09

### Fixed

- **App crashed on first launch / first onboarding click on every
  user's machine — the actual root cause behind the v0.1.1, v0.1.2
  and v0.1.3 attempts.** The crash signature in user-side
  diagnostic reports was always the same: SwiftPM's auto-generated
  `Bundle.module` accessor calling `fatalError` because it couldn't
  locate `Timap_TimapCore.bundle`. The accessor looks in
  `Bundle.main.bundleURL/Timap_TimapCore.bundle`, which for a real
  `.app` resolves to `Timap.app/Timap_TimapCore.bundle` (top-level
  of the bundle) — but the Makefile copied the resource bundle
  into `Contents/MacOS/` instead, so it was never found. The
  accessor's second fallback is a hard-coded absolute path inside
  the build dir (`/Users/jvever/Code/.../.build/release/...`),
  which only existed on the developer's own machine. That's why
  v0.1.1–0.1.3 ran fine locally but crashed for everyone else.
  The earlier "popover dismissed on click" theories were all
  wrong: the popover wasn't dismissing, the entire process was
  segfaulting after the SwiftUI view recomposed and accessed
  `CityCatalog.all`, which lazy-initializes via `Bundle.module`.
  Fix is two-pronged: (1) `CityCatalog` now searches a list of
  candidate paths (`Contents/Resources/cities.json` first, then
  next-to-executable, then `Bundle.module` only when the SPM
  bundle is actually present) so the catalog never triggers the
  fatal accessor; (2) the Makefile now copies `cities.json`
  directly into `.app/Contents/Resources/` as the canonical
  location.

## [0.1.3] — 2026-05-09

### Fixed

- **Onboarding popover dismissed on inside clicks (the v0.1.2
  fix didn't actually fix it).** Switching to
  `popover.behavior = .applicationDefined` in v0.1.2 should have
  stopped AppKit from auto-closing the popover, but in real
  macOS 15+ environments the popover still dismissed on the
  first button tap — verified in the wild after the v0.1.2
  release. Root cause: my own outside-click monitor was firing
  for mouse-down events that landed inside the popover. On
  macOS 15+ the global event monitor receives in-popover
  clicks under LSUIElement + non-key-window conditions
  (technically allowed but contrary to how the API behaves on
  macOS 13/14). Added a geometry check: ignore mouse-down
  events whose location falls inside the popover's window
  frame. Onboarding "Next" / "Get started" buttons now work
  on macOS 15 and 26.

## [0.1.2] — 2026-05-08

### Fixed

- **Onboarding popover dismissed on the first button click.** On
  macOS 15 (Sequoia) and 26 (Tahoe), `NSPopover.behavior =
  .transient` started treating clicks on the popover's *own*
  buttons as "user interacted, dismiss me" — clicking "下一步" /
  "Next" on the welcome screen closed the whole popover before
  the button's action could run. Switched the popover behavior
  to `.applicationDefined` and now manage dismissal entirely
  through the existing global outside-click monitor plus a new
  local Esc-key monitor. Buttons inside the popover work
  correctly again.

### Changed

- README install troubleshooting reordered: the Terminal `xattr`
  command is now Method 1 (it always works), and System Settings
  → Open Anyway is Method 2 with an explicit warning that the
  "Open Anyway" button often doesn't appear on macOS 15 / 26 for
  ad-hoc-signed apps. The "Timap is damaged" dialog wording is
  now also explicitly called out and reassured.

## [0.1.1] — 2026-05-08

### Fixed

- **First-launch UX:** double-clicking `Timap.app` from `/Applications`
  now auto-opens the popover when the user hasn't completed
  onboarding, so a brand-new install no longer looks broken (it's
  an `LSUIElement` app with no Dock icon, and the menu-bar globe
  was easy to miss on a crowded bar).
- Re-launching an already-running Timap (double-clicking the app
  while it's alive) now also pops the popover via
  `applicationShouldHandleReopen`, instead of doing nothing. This
  is also the answer for users on notched MacBooks whose menu-bar
  icon ends up hidden behind the notch — re-launch the app and
  the popover comes back.

### Changed

- README copy: replaced jargon ("全队 / pin / 全员重叠窗口") with
  reader-friendlier wording, dropped the brittle right-click-Open
  install method (it doesn't work on macOS 14 / 15), simplified
  install down to two methods (System Settings → Open Anyway, or
  the `xattr` CLI), and added guidance for users whose menu-bar
  icon gets hidden behind the notch.
- v0.1.0 release notes rewritten as Chinese-first bilingual.

## [0.1.0] — 2026-05-07

Initial public release.

### Added

- macOS menu-bar app showing a live world map with day/night terminator.
- 24-hour time slider with 30-min snapping; drag to scrub time, click "Now" to snap back to live.
- City cards with per-city working hours (0.5h step) and inline teammate chips with avatars.
- Best-meeting-window finder: ranks 30-min windows by team-overlap × duration.
- Two-step onboarding: animated brand logo + value prop, followed by a city picker with hot-city chips and a live "Now H:MM" preview in the picked timezone.
- Bilingual UI (Chinese / English) switchable from the welcome screen and Settings.
- IANA-timezone storage so DST jumps follow the real calendar (Berlin / London / NY / Sydney all handled automatically).
- Avatar upload (PNG/JPEG, scaled to 192px on the long edge) with initial-circle fallback.
- Manual city entry for cities not in the bundled ~80-city catalog.
- "Hide a city" toggle (cities still show on the map but don't count toward best-window scoring).
- DMG distribution via GitHub Releases.

### Engineering notes

- Three-target SPM split: `TimapCore` (pure logic), `Timap` (SwiftUI), `TimapVerify` (assertion-style regression checks — the de-facto test suite, since CLT-only environments don't ship XCTest).
- Headless screenshot tool (`TimapShot` + `make screenshot`) for capturing the popover via distributed notifications.
- Brand identity: SVG logo source, programmatically-drawn menu-bar template icon, regenerable `.icns` via `make icon`.

[Unreleased]: https://github.com/JVever/Timap/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/JVever/Timap/releases/tag/v0.1.4
[0.1.3]: https://github.com/JVever/Timap/releases/tag/v0.1.3
[0.1.2]: https://github.com/JVever/Timap/releases/tag/v0.1.2
[0.1.1]: https://github.com/JVever/Timap/releases/tag/v0.1.1
[0.1.0]: https://github.com/JVever/Timap/releases/tag/v0.1.0

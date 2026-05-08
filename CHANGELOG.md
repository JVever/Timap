# Changelog

All notable changes to Timap are tracked here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [SemVer](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/JVever/Timap/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/JVever/Timap/releases/tag/v0.1.1
[0.1.0]: https://github.com/JVever/Timap/releases/tag/v0.1.0

# Timap

English · [中文](README.md)

![Platform](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-GPL--3.0-green) ![Release](https://img.shields.io/github/v/release/JVever/Timap?label=release)

> **See your whole team's clock at a glance.**
> One click in the menu bar shows you who's asleep, who's at lunch, who's at their desk — laid out on a live world map. Drag the time slider, and the green meeting window for next Tuesday lights up by itself.

<p align="center">
  <img src="docs/screenshots/01-hero.png" width="520" alt="Timap main view: Beijing as the home city, teammates in Berlin and New York in different states, a 4-hour all-team overlap window highlighted on the time slider" />
</p>

For people who do three timezone math problems before opening Slack each morning. SwiftUI · Swift Package Manager · macOS 13+.

---

## What it does

- **🌍 Whole team on one live map** — A world map with day/night that follows the sun. The moment you open the app, you can tell who's deep in the night, who's at lunch, who just sat down at their desk.
- **🎚 Time slider, scrubbable** — Push the slider; every city card switches state in sync. "Will Maya in NYC still be awake at 10 PM Beijing next Tuesday?" Drag there. Answer's on the card.
- **✨ Auto-find shared work windows** — Computes the intersection of every teammate's working hours at 30-min granularity, ranks windows by team-overlap × duration. Click the time number top-left to jump to the next recommended slot.
- **🌐 Bilingual UI + IANA timezones** — Switch UI language with one click. Time zones aren't hardcoded UTC offsets — Berlin / London / New York DST jumps follow real calendar dates.
- **🏠 Quiet menu-bar resident** — No Dock icon, no space stolen. Click to open the popover, Esc to close, click anywhere outside to dismiss.

## What it deliberately doesn't do

To avoid scope creep:

- ❌ Calendar / EventKit integration (only timezones, not your schedule)
- ❌ Multi-day view (today only — next week is next week's problem)
- ❌ Team cloud sync (each person runs their own local copy, no networking)
- ❌ App Store distribution (ships via GitHub Releases)

## Install

### Option 1: Download the DMG (recommended)

1. Download `Timap-0.1.0.dmg` from [Releases](https://github.com/JVever/Timap/releases)
2. Open the DMG → drag `Timap.app` to Applications
3. First launch: right-click `Timap.app` → "Open" → confirm
4. Look for the Timap icon at the top of your menu bar; click to open

<details>
<summary>Hit "unidentified developer" warning?</summary>

This app isn't signed with a $99 Apple Developer ID, so macOS Gatekeeper blocks it once. Plenty of macOS utilities walked the same path — right-click "Open" once and you're done.

If you'd rather skip the right-click dance, this one-liner is equivalent:

```sh
xattr -d com.apple.quarantine /Applications/Timap.app
```

After that, double-click works normally.

</details>

### Option 2: Build from source

```sh
git clone https://github.com/JVever/Timap.git
cd Timap/Timap
make run
```

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

## Three-step quickstart

### 1. Pick your city

First launch shows the welcome screen: a logo assembly animation plus three value-prop bullets (see morning/afternoon/night across every city · spot windows where everyone's in working hours · lives in the menu bar). Next, pick your city as your home time zone.

<p align="center">
  <img src="docs/screenshots/06-onboarding-welcome.png" width="240" alt="Welcome screen with assembled logo" />
  <img src="docs/screenshots/07-onboarding-citypick.png" width="240" alt="City picker: 5 popular-city chips and the full searchable list" />
  <img src="docs/screenshots/08-onboarding-citypick-selected.png" width="240" alt="Beijing selected — green preview card and active CTA appear at the bottom" />
</p>

<p align="center"><sub>Welcome → pick your city → confirm</sub></p>

### 2. Add teammates

Open Settings (gear icon) → click "+ Teammate" on each city card to add team members; "+ Add city" at the bottom for new cities. Each teammate's working hours can be set independently (30-min steps), avatars support image upload or auto-generated initials. Cities not in the catalog can be added manually with lat/lng.

<p align="center">
  <img src="docs/screenshots/04-settings.png" width="420" alt="Settings page: one card per city, adjustable working hours, teammate chips with avatar and name" />
</p>

### 3. Read the map

Back on the main view:

| Action | Result |
|---|---|
| Drag the slider | Every city card updates in sync |
| Click the time number top-left | Jump to the next recommended meeting window |
| Click a city name | Hide / include that city (hidden cities don't count toward overlap, but still show on the map) |
| Click "Now" | Snap back to live time |

## For contributors

Solo-maintained. PRs and issues welcome.

### Repo layout

```
.
├── Timap/                         # The macOS app (SPM package, no .xcodeproj)
│   ├── Package.swift
│   ├── Makefile                   # All daily commands
│   ├── Resources/                 # App icons
│   └── Sources/
│       ├── TimapCore/             # Pure logic (data / time math / geo / persistence) — no UI deps
│       ├── Timap/                 # SwiftUI view layer
│       └── TimapVerify/           # Assertion-style test suite (de-facto swift test, see below)
├── prototype/                     # React/Babel HTML design prototypes (visual spec source)
├── logo/                          # Brand SVG sources
├── docs/screenshots/              # Screenshots for this README
└── CLAUDE.md                      # Detailed architecture / conventions / gotchas
```

### Where to look when…

| Want to do | Edit / read |
|---|---|
| Add a city | `Timap/Sources/TimapCore/Resources/cities.json` |
| Add new UI / tweak layout | `Timap/Sources/Timap/Views/` |
| Adjust time math / persistence / geo | `Timap/Sources/TimapCore/` + add a check in `TimapVerify/main.swift` |
| Add or change copy / i18n | `Timap/Sources/TimapCore/Models/L10n.swift` (update zh and en together) |
| Change menu-bar / Dock icon | `Timap/Sources/Timap/Brand/BrandIcon.swift` or `Timap/Resources/Timap-AppIcon.svg` |
| Tweak the onboarding flow | `Timap/Sources/Timap/Views/OnboardingView.swift` |

### Common commands

```sh
cd Timap
make verify    # Run TimapCore assertions (the de-facto test suite)
make run       # Build + launch
make install   # Copy to /Applications
make dmg       # Build the DMG installer
make reset     # Wipe persisted state — back to first-launch (essential when iterating on onboarding)
```

### Why `make verify` instead of `swift test`

A Command-Line-Tools-only macOS install (no full Xcode) doesn't ship XCTest, so `swift test` won't run. Instead, the `TimapVerify` executable target uses a plain `check(condition, "name")` pattern to cover every branch in `TimapCore`. **When you change logic in `TimapCore`, add a corresponding check in `TimapVerify/main.swift`** — that's the repo's only regression net.

For deeper architecture notes, design decisions, and gotchas, see [CLAUDE.md](CLAUDE.md).

## License

[GPL-3.0](LICENSE) · Copyright © 2026 [JVever](https://github.com/JVever)

> Timap is free software — use, modify, and distribute it freely; if you distribute a modified version, you must keep it open under GPL-3.0.

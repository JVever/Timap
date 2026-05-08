# Timap

English · [中文](README.md)

![Platform](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-GPL--3.0-green) ![Release](https://img.shields.io/github/v/release/JVever/Timap?label=release)

> **See your whole team's clock at a glance.**
> One click in the menu bar shows you who's asleep, who's at lunch, who's at their desk — laid out on a live world map. Drag the time slider, and the green meeting window for next Tuesday lights up by itself.

<p align="center">
  <img src="docs/screenshots/01-hero.png" width="520" alt="Timap main view: Beijing as the home city, teammates in Berlin and New York in different states, a 4-hour all-team overlap window highlighted on the time slider" />
</p>

## What it does

- **🌍 Whole team on one live map** — A world map with day/night that follows the sun. The moment you open the app, you can tell who's deep in the night, who's at lunch, who just sat down at their desk.
- **🎚 Time slider, scrubbable** — Push the slider; every city card switches state in sync. "Will Maya in NYC still be awake at 10 PM Beijing next Tuesday?" Drag there. Answer's on the card.
- **✨ Auto-find shared work windows** — Computes the intersection of every teammate's working hours at 30-min granularity, ranks windows by team-overlap × duration. Click the time number top-left to jump to the next recommended slot.
- **🌐 Bilingual UI + IANA timezones** — Switch UI language with one click. Time zones aren't hardcoded UTC offsets — Berlin / London / New York DST jumps follow real calendar dates.
- **🏠 Quiet menu-bar resident** — No Dock icon, no space stolen. Click to open the popover, Esc to close, click anywhere outside to dismiss.

## Install

### Option 1: Download the DMG (recommended)

1. Download `Timap-0.1.0.dmg` from [Releases](https://github.com/JVever/Timap/releases)
2. Open the DMG → drag `Timap.app` to Applications
3. Double-click Timap (**a "can't be opened" dialog will pop up the first time** — see how to handle it below)
4. Once it opens, the Timap icon appears at the top of your menu bar

#### A "can't be opened" dialog appears the first time — here's how to handle it

The first time you double-click Timap, macOS will block it and show a dialog like (wording varies a bit by macOS version):

> "Timap can't be opened because it is from an unidentified developer"
>
> "Apple could not verify Timap is free of malware"

This is macOS's built-in safety check for any app not installed from the App Store — **it's not a problem with Timap**. **You only need to handle this once**; double-clicking after that just works.

Pick **any one** of the three methods below:

<details>
<summary><b>Method A: Right-click Open — simplest, try this first</b></summary>

Works on most macOS 13 / 14 systems.

1. Open Finder → `/Applications` and locate `Timap.app`
2. **Hold `Control` and click** (or two-finger click on a trackpad) `Timap.app`
3. Choose **"Open"** from the context menu
4. This time the warning dialog has an **"Open"** button — click it
5. Future double-clicks just work

> Note: only the right-click "Open" path produces a clickable "Open" button. A normal double-click shows a dialog with only "Cancel" and "Move to Trash".

</details>

<details>
<summary><b>Method B: Click "Open Anyway" in System Settings — use this if Method A doesn't work</b></summary>

For macOS 14 (Sonoma) and 15 (Sequoia). On these versions Method A often hides the "Open" button — you'll need to allow Timap from System Settings instead.

1. Double-click `Timap.app` to trigger the block dialog, then click "Done" or "Cancel" to dismiss it
2. Open **System Settings** → on the left, choose **Privacy & Security**
3. **Scroll to the bottom** of the right-hand pane to the "Security" section; you'll see:
   > "Timap" was blocked from use because it is not from an identified developer.
4. Click the **"Open Anyway"** button on the right
5. Confirm once more when prompted (Mac password or Touch ID may be required)
6. Future double-clicks just work

</details>

<details>
<summary><b>Method C: One-line Terminal command — for command-line folks</b></summary>

Works on all macOS versions.

Open **Terminal.app**, paste and press Enter:

```sh
xattr -d com.apple.quarantine /Applications/Timap.app
```

After that, double-clicking Timap opens it directly.

If you see `No such xattr` or `No such file or directory` — Timap already doesn't need this; just double-click it.

> **What this command does:** macOS adds a hidden "downloaded from the internet" tag to any file that came from a browser, which triggers an extra safety check. The command removes that tag from Timap so the system treats it like any other locally-installed app. **It only affects this single copy of Timap.app — your Mac's overall security settings are unchanged.**

</details>

> **None of the three methods worked?** Likely a corrupted DMG download or a new restriction in your macOS version. Please open an [Issue](https://github.com/JVever/Timap/issues) with your macOS version and the exact error text — I'll follow up.

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
  <img src="docs/screenshots/08-onboarding-citypick-selected.png" width="240" alt="Beijing selected — green preview card and active 'Get started' button appear at the bottom" />
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

## License

[GPL-3.0](LICENSE) · Copyright © 2026 [JVever](https://github.com/JVever)

> Timap is free software — use, modify, and distribute it freely; if you distribute a modified version, you must keep it open under GPL-3.0.

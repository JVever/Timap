# Timap

English · [中文](README.md)

![Platform](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-GPL--3.0-green) ![Release](https://img.shields.io/github/v/release/JVever/Timap?label=release)

> **See every teammate's clock at a glance.**
> One click in the menu bar shows you who's asleep, who's at lunch, who's at their desk — laid out on a live world map. Drag the time slider, and the green meeting window for next Tuesday lights up by itself.

<p align="center">
  <img src="docs/screenshots/01-hero.png" width="520" alt="Timap main view: Beijing as the home city, teammates in Berlin and New York in different states, a 4-hour 'everyone-can-meet' window highlighted on the time slider" />
</p>

## What it does

- **🌍 Every teammate's city, plotted on a live map** — A world map with each teammate's city pinned, plus a day/night terminator that moves in real time. The moment you open the app, you can tell who's deep in the night, who's at lunch, who just sat down at their desk.
- **🎚 Time slider, scrubbable** — Push the slider; every city card switches state in sync. "Will Maya in NYC still be awake at 10 PM Beijing next Tuesday?" Drag there. Answer's on the card.
- **✨ Auto-find times when everyone can meet** — Intersects each city's working hours at 30-min granularity, ranks the resulting windows by team-overlap × duration. Click the time number top-left to jump to the next recommended slot.

## Install

### Option 1: Download the DMG (recommended)

1. Open the [Releases page](https://github.com/JVever/Timap/releases) → under the latest version's **Assets** section, click `Timap-0.1.4.dmg` to download
2. Open the downloaded DMG → drag `Timap.app` to your Applications folder
3. Double-click Timap (**a "can't be opened" dialog will pop up the first time** — see how to handle it below)
4. After unblocking, double-click again and **the welcome screen pops up automatically**; just follow the prompts. After that, Timap lives in the **top-right menu bar** (icon: a black-framed three-bar mark) — click it any time to use the app

#### macOS will block the first launch — here's how to get through it

The first time you double-click Timap, macOS will refuse to open it and show one of these dialogs (wording differs across macOS versions):

> **"Timap" is damaged and can't be opened. You should move it to the Trash.**
>
> "Timap can't be opened because it is from an unidentified developer"
>
> "Apple could not verify Timap is free of malware"

> ⚠️ **Don't be alarmed by "is damaged".** The file isn't actually damaged. This is macOS 15 (Sequoia) and 26 (Tahoe)'s harshest dialog for apps that aren't notarized by Apple — the literal wording says "damaged", but the file is fine; the system just refuses to run it. **Nothing's wrong with Timap.**

**You only need to handle this once**; future double-clicks just work.

##### Method 1: One-line Terminal command (recommended · works on any macOS)

Open **Terminal.app** — search "terminal" in Spotlight and press Enter.

Paste this line into the Terminal window and press Enter:

```sh
xattr -d com.apple.quarantine /Applications/Timap.app
```

If you see `Operation not permitted`, use the `sudo` variant instead (it'll prompt for your Mac password — typing is invisible, that's normal):

```sh
sudo xattr -cr /Applications/Timap.app
```

Then double-click Timap — **it should just open**.

> **What this command does:** macOS silently tags every file your browser downloads with a "from-the-internet" attribute that triggers extra safety checks. This command strips that tag from Timap so the system treats it as a regular local app. **It only affects this one copy of Timap.app — your Mac's overall security settings are unchanged.**

##### Method 2: Click "Open Anyway" in System Settings (often missing on macOS 15+)

> ⚠️ **On macOS 15 and 26 — especially when you saw the "is damaged" dialog — the "Open Anyway" button often doesn't appear at all.** Apple removed this escape hatch for the harshest blocks. If your dialog was the milder "unidentified developer" version this path may still work; if you saw "is damaged", go back and use Method 1.

1. Double-click `Timap.app` to trigger the block dialog, then click "Done" or "Cancel" to dismiss it
2. Open **System Settings** → on the left, choose **Privacy & Security**
3. **Scroll to the bottom** of the right-hand pane to the "Security" section and look for:
   > "Timap" was blocked from use because it is not from an identified developer.
4. If you see it, click **"Open Anyway"** on the right → confirm in the next dialog (Mac password or Touch ID may be required)
5. If that line **isn't there at all** → your system doesn't offer this path; go use Method 1

> **Neither method worked?** Likely a corrupted DMG download or a new restriction in your macOS version. Please open an [Issue](https://github.com/JVever/Timap/issues) with your macOS version and the exact error text — I'll follow up.

### Option 2: Build from source

```sh
git clone https://github.com/JVever/Timap.git
cd Timap/Timap
make run
```

Requires macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

### Can't find the Timap icon in your menu bar?

On notched MacBooks (Pro 14"/16" or Air 13"/15"), if your menu bar is crowded, Timap's icon may be hidden behind the notch and unclickable. Two ways out:

- **Open Timap without the menu-bar icon** — just **double-click `/Applications/Timap.app`** (or launch from Spotlight / Launchpad). The main view pops up directly.
- **Fix it permanently with a menu-bar manager.** Free, open-source picks:
  - [Hidden Bar](https://github.com/dwarvesf/hidden) — minimal, just shows/hides
  - [Ice](https://github.com/jordanbaird/Ice) — fuller-featured

## Three-step quickstart

### 1. Pick your city

Follow the welcome screen's prompts to pick your city as your home time zone.

<p align="center">
  <img src="docs/screenshots/06-onboarding-welcome.png" width="240" alt="Welcome screen with assembled logo" />
  <img src="docs/screenshots/07-onboarding-citypick.png" width="240" alt="City picker: 5 popular-city quick picks and the full searchable list" />
  <img src="docs/screenshots/08-onboarding-citypick-selected.png" width="240" alt="Beijing selected — green preview card and active 'Get started' button appear at the bottom" />
</p>

<p align="center"><sub>Welcome → pick your city → confirm</sub></p>

### 2. Add teammates

Open Settings (gear icon) → click "+ Teammate" on each city card to add team members; "+ Add city" at the bottom for new cities. Working hours are set **per city** (everyone in the same city shares one schedule), which keeps adjustments quick.

<p align="center">
  <img src="docs/screenshots/04-settings.png" width="420" alt="Settings page: one card per city, adjustable working hours, teammate tags with avatar and name" />
</p>

### 3. Use it

Back on the main view, the moves worth knowing:

- **Drag the slider** — every city card updates to that moment in sync
- **Click the time number top-left** — jumps to the next slot when everyone can meet
- **Click a city's name** — hides / includes that city (hidden cities still show on the map but don't count toward the shared-meeting calculation)
- **Click "Now"** — snaps back to live time

## License

[GPL-3.0](LICENSE) · Copyright © 2026 [JVever](https://github.com/JVever)

> Timap is free software — use, modify, and distribute it freely; if you distribute a modified version, you must keep it open under GPL-3.0.

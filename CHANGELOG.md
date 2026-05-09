# Changelog

All notable changes to Timap are tracked here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.6] — 2026-05-09

### Changed

- **Onboarding 城市选择页改版**。常用城市从 5 个扩到 12 个
  （北京、上海、香港、东京、首尔、新加坡 / 悉尼、伦敦、柏林、
  纽约、旧金山、多伦多），按地理顺序两行铺开，覆盖中国用户
  跨海外协作时最常碰到的时区。query 为空时不再展示底部
  "全量"列表（之前展示的是 cities.json 的前 8 项，恰好全是
  中国城市，和上方"常用城市"chip 语义重叠让人困惑），改为
  仅展示 12 个 chip；输入搜索词时再切换到结果列表。
- **列表项副标题去重**。原来中文界面下显示 "CN · Beijing"，
  和左边的 CN 徽章 + 标题里的"北京"三处都在重复同一个国家
  信息加一个拼音；改为 GMT 偏移（如 "GMT+9"、"GMT−5"），是
  用户挑选时区时真正有用的区分维度。
- **返回按钮提到顶栏**。和右上角的语言切换按钮平行（不再
  挤在标题左侧），cityPick 的标题 + 说明独立成段，整体内容
  下移让视觉重心向 welcome 页靠拢。
- **主面板左上角大时间统一成 24 小时制**（之前是 12 小时
  AM/PM，城市卡片和地图标签是 24h，三处不一致）。跨时区
  会议工具更看重无歧义——"23:00"和"11:00 PM"前者一眼无
  误读，后者容易和 11 AM / 凌晨 12 点等混淆。

### Fixed

- **选中某个常用城市后，标题 / 搜索框 / chips 集体上跳**。
  picked 状态出现 SelectedPreview 让 footer 高度从 ~67px 增到
  ~127px，body 区的 Spacer 重新分配，上方所有元素跟着上移
  ~30px。改为给 SelectedPreview 预留固定 60px 占位（picked
  为空时是透明 placeholder），footer 高度恒定，body 不再
  reflow。

## [0.1.5] — 2026-05-09

### Fixed

- **Timap 不出现在 Launchpad 里**（Spotlight 能搜到、菜单栏图标也正常，
  但启动台空空）。我之前给的解释"`LSUIElement=YES` 的 app 都不在
  Launchpad"是错的——Hidden Bar 等同类菜单栏 app 都设了
  `LSUIElement=YES` 却照样出现在启动台。对照 Hidden Bar 的
  `Info.plist` 后定位到真正缺失的元数据：`LSApplicationCategoryType`
  + `CFBundleInfoDictionaryVersion` + `CFBundleDevelopmentRegion`
  + `NSHumanReadableCopyright`。Apple 对"什么算合法 app"的判定
  不光看可执行文件，还看这些标准 Info.plist 字段——缺了几个
  Launchpad 就把它当成残缺 app 默默跳过。Makefile 的 `Info.plist`
  生成模板已补齐。Spotlight `mdls` 验证现在能正确给 Timap 打上
  "实用工具"分类。

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

[Unreleased]: https://github.com/JVever/Timap/compare/v0.1.6...HEAD
[0.1.6]: https://github.com/JVever/Timap/releases/tag/v0.1.6
[0.1.5]: https://github.com/JVever/Timap/releases/tag/v0.1.5
[0.1.4]: https://github.com/JVever/Timap/releases/tag/v0.1.4
[0.1.3]: https://github.com/JVever/Timap/releases/tag/v0.1.3
[0.1.2]: https://github.com/JVever/Timap/releases/tag/v0.1.2
[0.1.1]: https://github.com/JVever/Timap/releases/tag/v0.1.1
[0.1.0]: https://github.com/JVever/Timap/releases/tag/v0.1.0

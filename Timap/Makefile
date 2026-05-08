APP_NAME := Timap
VERSION  := 0.1.2
APP_DIR  := dist/$(APP_NAME).app
DMG_PATH := dist/$(APP_NAME)-$(VERSION).dmg
DMG_STAGE:= dist/dmg-staging
EXE      := .build/release/$(APP_NAME)
BUNDLE   := .build/release/Timap_TimapCore.bundle
ICON_SRC := Resources/Timap-AppIcon.svg
ICON     := Resources/Timap.icns

.PHONY: all build bundle run verify reset clean install dmg screenshot icon help

all: bundle

build:
	swift build -c release

bundle: build $(ICON)
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@mkdir -p "$(APP_DIR)/Contents/Resources"
	@cp "$(EXE)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	@cp -R "$(BUNDLE)" "$(APP_DIR)/Contents/MacOS/"
	@cp "$(ICON)" "$(APP_DIR)/Contents/Resources/Timap.icns"
	@printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'    <key>CFBundleName</key><string>Timap</string>' \
'    <key>CFBundleDisplayName</key><string>Timap</string>' \
'    <key>CFBundleIdentifier</key><string>com.timap.app</string>' \
'    <key>CFBundleVersion</key><string>1</string>' \
'    <key>CFBundleShortVersionString</key><string>0.1.2</string>' \
'    <key>CFBundleExecutable</key><string>Timap</string>' \
'    <key>CFBundlePackageType</key><string>APPL</string>' \
'    <key>CFBundleIconFile</key><string>Timap</string>' \
'    <key>LSMinimumSystemVersion</key><string>13.0</string>' \
'    <key>LSUIElement</key><true/>' \
'    <key>NSHighResolutionCapable</key><true/>' \
'    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>' \
'</dict>' \
'</plist>' > "$(APP_DIR)/Contents/Info.plist"
	@echo "✓ Built $(APP_DIR)"
	@echo "  Run with: make run    (or)    open $(APP_DIR)"

# Regenerate Timap.icns from the colored brand SVG. The .icns is checked in,
# so this only needs to run when the brand SVG changes. Uses sips (built-in
# SVG → PNG) and iconutil to package the iconset.
$(ICON): $(ICON_SRC)
	@echo "→ Generating $(ICON) from $(ICON_SRC)"
	@ICONSET="$$(mktemp -d)/Timap.iconset"; mkdir -p "$$ICONSET"; \
	gen() { sips -s format png -Z "$$1" "$(ICON_SRC)" --out "$$ICONSET/$$2.png" >/dev/null; }; \
	gen 16   icon_16x16; \
	gen 32   icon_16x16@2x; \
	gen 32   icon_32x32; \
	gen 64   icon_32x32@2x; \
	gen 128  icon_128x128; \
	gen 256  icon_128x128@2x; \
	gen 256  icon_256x256; \
	gen 512  icon_256x256@2x; \
	gen 512  icon_512x512; \
	gen 1024 icon_512x512@2x; \
	iconutil -c icns "$$ICONSET" -o "$(ICON)"
	@echo "✓ $(ICON)"

icon: $(ICON)

run: bundle
	@open "$(APP_DIR)"
	@echo "✓ Launched $(APP_NAME). Look for the globe icon in your menu bar."

verify:
	swift run TimapVerify

# Reset onboarding + persisted team to first-launch state. Useful when
# iterating on the onboarding UI: `make reset` then re-open Timap.app to
# see the OnboardingView again.
reset:
	@pkill -x Timap 2>/dev/null || true
	@defaults delete com.timap.app 2>/dev/null || true
	@echo "✓ Cleared persisted state for com.timap.app"
	@echo "  Re-launch with: open /Applications/Timap.app"

clean:
	rm -rf .build dist

install: bundle
	@cp -R "$(APP_DIR)" /Applications/
	@echo "✓ Installed to /Applications/$(APP_NAME).app"

# Package the .app into a compressed read-only .dmg with a drag-to-Applications
# layout. Output lands at $(DMG_PATH).
dmg: bundle
	@rm -rf "$(DMG_STAGE)"
	@rm -f "$(DMG_PATH)"
	@mkdir -p "$(DMG_STAGE)"
	@cp -R "$(APP_DIR)" "$(DMG_STAGE)/"
	@ln -s /Applications "$(DMG_STAGE)/Applications"
	@hdiutil create \
		-volname "$(APP_NAME)" \
		-srcfolder "$(DMG_STAGE)" \
		-ov -format UDZO -fs HFS+ \
		"$(DMG_PATH)" >/dev/null
	@rm -rf "$(DMG_STAGE)"
	@SIZE=$$(du -h "$(DMG_PATH)" | cut -f1); \
	 echo "✓ Built $(DMG_PATH) ($$SIZE)"
	@echo "  双击打开后，把 Timap 拖到 Applications 即可安装。"

# Headless screenshot of the Timap popover. Requires Timap.app to be running.
# Usage: make screenshot [OUT=/tmp/foo.png]
OUT ?= /tmp/timap-shot-$(shell date +%s).png
screenshot:
	@swift build -c release --product TimapShot 2>&1 | tail -1
	@.build/release/TimapShot "$(OUT)"

help:
	@echo "make           — 构建并打包成 dist/Timap.app"
	@echo "make run       — 构建、打包，并启动 Timap"
	@echo "make verify    — 运行 TimapCore 正确性校验"
	@echo "make install   — 把 Timap.app 复制到 /Applications"
	@echo "make dmg       — 生成 dist/Timap-<version>.dmg 安装镜像"
	@echo "make screenshot[OUT=...]  — 让运行中的 Timap 自截 popover 截图"
	@echo "make icon      — 从 Resources/Timap-AppIcon.svg 重新生成 Timap.icns"
	@echo "make reset     — 清空持久化数据，回到首次启动状态（测 onboarding 用）"
	@echo "make clean     — 清理构建产物和 dist"

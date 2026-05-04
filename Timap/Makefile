APP_NAME := Timap
VERSION  := 0.1.0
APP_DIR  := dist/$(APP_NAME).app
DMG_PATH := dist/$(APP_NAME)-$(VERSION).dmg
DMG_STAGE:= dist/dmg-staging
EXE      := .build/release/$(APP_NAME)
BUNDLE   := .build/release/Timap_TimapCore.bundle

.PHONY: all build bundle run verify clean install dmg screenshot help

all: bundle

build:
	swift build -c release

bundle: build
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@mkdir -p "$(APP_DIR)/Contents/Resources"
	@cp "$(EXE)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	@cp -R "$(BUNDLE)" "$(APP_DIR)/Contents/MacOS/"
	@printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'    <key>CFBundleName</key><string>Timap</string>' \
'    <key>CFBundleDisplayName</key><string>Timap</string>' \
'    <key>CFBundleIdentifier</key><string>com.timap.app</string>' \
'    <key>CFBundleVersion</key><string>1</string>' \
'    <key>CFBundleShortVersionString</key><string>0.1.0</string>' \
'    <key>CFBundleExecutable</key><string>Timap</string>' \
'    <key>CFBundlePackageType</key><string>APPL</string>' \
'    <key>LSMinimumSystemVersion</key><string>13.0</string>' \
'    <key>LSUIElement</key><true/>' \
'    <key>NSHighResolutionCapable</key><true/>' \
'    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>' \
'</dict>' \
'</plist>' > "$(APP_DIR)/Contents/Info.plist"
	@echo "✓ Built $(APP_DIR)"
	@echo "  Run with: make run    (or)    open $(APP_DIR)"

run: bundle
	@open "$(APP_DIR)"
	@echo "✓ Launched $(APP_NAME). Look for the globe icon in your menu bar."

verify:
	swift run TimapVerify

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
	@echo "make clean     — 清理构建产物和 dist"

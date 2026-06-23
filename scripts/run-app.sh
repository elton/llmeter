#!/usr/bin/env bash
# Build LLMeter and wrap it into a minimal .app bundle, then launch it.
#
# Why: the menu-bar app uses SwiftUI `MenuBarExtra` and `UserNotifications`, both
# of which require the process to be a real `.app` bundle with a bundle identifier.
# Running the bare SPM executable (`swift run LLMeter`) shows no status-bar icon and
# silently drops notifications. This wraps the built binary so both work locally.
#
# Usage:
#   scripts/run-app.sh            # debug build
#   scripts/run-app.sh release    # release build
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "▶︎ Building LLMeter ($CONFIG)…"
swift build -c "$CONFIG" --product LLMeter

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/LLMeter"
APP="$BIN_DIR/LLMeter.app"
MACOS="$APP/Contents/MacOS"

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$BIN" "$MACOS/LLMeter"

# Resource bundles (localization .lproj live inside) go in the STANDARD
# Contents/Resources location. A bundle in the .app root is "unsealed content"
# that makes codesign fail → the app gets an unstable/ad-hoc identity → macOS
# re-prompts for the keychain on every launch. With the bundle in Contents/Resources
# the .app signs cleanly; Bundle.module then resolves the resources via SwiftPM's
# built-in .build fallback path, which is always present on this dev machine
# (run-app.sh rebuilds every run). For distribution (M4) the bundles are placed by
# the signing/notarization pipeline, not this script.
mkdir -p "$APP/Contents/Resources"
for b in "$BIN_DIR"/*.bundle; do
    case "$b" in *Tests.bundle) continue ;; esac   # skip test resource bundles
    [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>LLMeter</string>
  <key>CFBundleDisplayName</key><string>LLMeter</string>
  <key>CFBundleIdentifier</key><string>com.eltonzheng.llmeter</string>
  <key>CFBundleExecutable</key><string>LLMeter</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
    <string>ja</string>
    <string>ko</string>
  </array>
  <key>NSHumanReadableCopyright</key><string>© 2026 Elton Zheng</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so the .app carries a code signature; the standard Contents/Resources
# layout above keeps codesign from failing on "unsealed" root content. By default the
# app has no app-OAuth keychain item and reads the Codex CLI credentials in ~/.codex,
# so the unstable ad-hoc identity does not trigger repeated keychain prompts. (Only an
# in-app "Sign in with ChatGPT" would store a keychain token; a stable, trusted
# signature for that case comes with distribution signing/notarization in M4.)
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "▶︎ Relaunching…"
pkill -x LLMeter 2>/dev/null || true
sleep 0.5
# `open` can race with LaunchServices right after pkill (error -600). Retry once,
# then fall back to launching the binary directly — it still runs inside the real
# .app bundle (Bundle.main resolves to the .app), so the menu-bar icon and
# notifications behave the same.
if ! open "$APP" 2>/dev/null; then
  sleep 1
  open "$APP" 2>/dev/null || nohup "$MACOS/LLMeter" >/dev/null 2>&1 &
fi
echo "✓ LLMeter 已启动 — 看屏幕右上角菜单栏的图标（🟢/🟠/🔴）。"
echo "  退出：在面板里退出，或运行  pkill -x LLMeter"

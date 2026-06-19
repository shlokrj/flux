#!/usr/bin/env bash
#
# Builds Flux and wraps the SPM binary in a minimal .app bundle so the menu bar
# item actually shows up, then launches it. A menu bar app needs an app bundle
# with LSUIElement set - `swift run` alone won't cut it.
#
# Usage: ./scripts/run.sh [debug|release]   (default: debug)
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"

echo "building Flux ($CONFIG)..."
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP=".build/Flux.app"

echo "packaging ${APP}..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/Flux" "$APP/Contents/MacOS/Flux"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Flux</string>
    <key>CFBundleIdentifier</key><string>com.flux.app</string>
    <key>CFBundleName</key><string>Flux</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Relaunch cleanly if a previous instance is running.
killall Flux 2>/dev/null || true

echo "launching Flux - look for the gauge in your menu bar (top-right)."
open "$APP"

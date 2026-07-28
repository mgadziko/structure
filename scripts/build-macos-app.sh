#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Structure.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICONSET="$ROOT/Resources/StructureIcon.iconset"
ICON="$ROOT/Resources/StructureIcon.icns"
BUILD_TIMESTAMP="$(date +%y%m%d-%H%M)"

swift build -c release --package-path "$ROOT"

swift "$ROOT/scripts/generate-app-icon.swift" "$ROOT"
iconutil -c icns "$ICONSET" -o "$ICON"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/Structure" "$MACOS/Structure"
cp "$ICON" "$RESOURCES/StructureIcon.icns"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Structure</string>
    <key>CFBundleIdentifier</key>
    <string>com.structure.prototype</string>
    <key>CFBundleName</key>
    <string>Structure</string>
    <key>CFBundleDisplayName</key>
    <string>Structure</string>
    <key>CFBundleIconFile</key>
    <string>StructureIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>StructureBuildTimestamp</key>
    <string>BUILD_TIMESTAMP_PLACEHOLDER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Set :StructureBuildTimestamp $BUILD_TIMESTAMP" "$CONTENTS/Info.plist"

printf 'Built %s\n' "$APP"

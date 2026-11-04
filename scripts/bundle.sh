#!/usr/bin/env bash
# Builds a release binary and wraps it in Flightdeck.app (menu bar only, no Dock icon).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Flightdeck.app"
BUNDLE_ID="com.magnuspladsen.Flightdeck"
VERSION="${VERSION:-$(cat "$ROOT/VERSION")}"
# Extra flags for swift build, e.g. "--arch arm64 --arch x86_64" for a universal release build
read -r -a BUILD_FLAGS <<< "${SWIFT_BUILD_FLAGS:-}"

cd "$ROOT"
swift build -c release --product Flightdeck ${BUILD_FLAGS[@]+"${BUILD_FLAGS[@]}"}
BINARY="$(swift build -c release --product Flightdeck ${BUILD_FLAGS[@]+"${BUILD_FLAGS[@]}"} --show-bin-path)/Flightdeck"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Flightdeck"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Flightdeck</string>
    <key>CFBundleDisplayName</key><string>Flightdeck</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>Flightdeck</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

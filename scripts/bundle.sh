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
BIN_PATH="$(swift build -c release --product Flightdeck ${BUILD_FLAGS[@]+"${BUILD_FLAGS[@]}"} --show-bin-path)"
# Sparkle reads its update feed from here; the matching private key is the SPARKLE_PRIVATE_KEY secret
FEED_URL="https://github.com/MagnusPladsen/flightdeck/releases/download/update-feed/appcast.xml"
PUBLIC_ED_KEY="82pqZdpi9TYcG4s3WUBLTVDP2WfoIugrkuZhbk5Xjvo="

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_PATH/Flightdeck" "$APP/Contents/MacOS/Flightdeck"
ditto "$BIN_PATH/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Flightdeck"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/CHANGELOG.md" "$APP/Contents/Resources/CHANGELOG.md"

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
    <key>NSAppleEventsUsageDescription</key><string>Flightdeck brings the terminal tab an agent runs in to the front.</string>
    <key>NSAudioCaptureUsageDescription</key><string>Flightdeck listens to what is playing to drive the now-playing visualiser. Nothing is recorded or saved.</string>
    <key>SUFeedURL</key><string>$FEED_URL</string>
    <key>SUPublicEDKey</key><string>$PUBLIC_ED_KEY</string>
</dict>
</plist>
PLIST

# Sparkle.framework keeps its own signature; this signs the app around it
codesign --force --sign - "$APP"
echo "Built $APP"

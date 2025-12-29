#!/bin/bash
# PokeScan App Installer
# Builds and installs PokeScan.app to /Applications

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POKESCAN_DIR="$(dirname "$SCRIPT_DIR")"
APP_PATH="/Applications/PokeScan.app"

echo "=== PokeScan App Installer ==="
echo ""

# Build release version
echo "Building PokeScan..."
cd "$POKESCAN_DIR"
swift build -c release 2>&1 | tail -3

# Remove old app if it exists
if [[ -d "$APP_PATH" ]]; then
    rm -rf "$APP_PATH"
    echo "Removed old app"
fi

# Create app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PokeScan</string>
    <key>CFBundleIdentifier</key>
    <string>com.pokescan.overlay</string>
    <key>CFBundleName</key>
    <string>PokeScan</string>
    <key>CFBundleDisplayName</key>
    <string>PokeScan</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
</dict>
</plist>
PLIST

# Copy binary
cp "$POKESCAN_DIR/.build/release/PokeScan" "$APP_PATH/Contents/MacOS/"

# SwiftPM resource bundles are resolved relative to the app root (Bundle.main.bundleURL),
# so place PokeScan_PokeScan.bundle next to Contents/.
RESOURCE_BUNDLE="$POKESCAN_DIR/.build/release/PokeScan_PokeScan.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    rm -rf "$APP_PATH/PokeScan_PokeScan.bundle"
    cp -R "$RESOURCE_BUNDLE" "$APP_PATH/PokeScan_PokeScan.bundle"
else
    echo "Warning: resource bundle not found at $RESOURCE_BUNDLE"
fi

echo ""
echo "Installed: $APP_PATH"
echo ""
echo "You can now launch PokeScan from Applications or Spotlight."
echo "Note: Start mGBA with the Lua script first, then launch PokeScan."

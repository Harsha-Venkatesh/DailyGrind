#!/bin/bash
# Builds DailyGrind, installs it to /Applications, and registers it to
# launch automatically at login via a per-user LaunchAgent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DailyGrind"
BUNDLE_ID="com.harsha.dailygrind"

echo "Building release binary..."
cd "$ROOT"
swift build -c release

echo "Packaging .app bundle..."
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 0.5

APP="$ROOT/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp ".build/release/JobGrindWidget" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Daily Grind</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Installing to /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP" "/Applications/$APP_NAME.app"

echo "Registering LaunchAgent (start at login)..."
mkdir -p ~/Library/LaunchAgents
PLIST_PATH=~/Library/LaunchAgents/$BUNDLE_ID.plist
cat > "$PLIST_PATH" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
AGENT

launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl enable "gui/$(id -u)/$BUNDLE_ID"

echo "Done. DailyGrind is installed and will launch at login."
echo "Look for the target icon in your menu bar."

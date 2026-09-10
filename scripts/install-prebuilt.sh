#!/bin/bash
# Installs the prebuilt DailyGrind.app (sitting next to this script) to
# /Applications and registers it to launch automatically at login.
# No Xcode / Swift toolchain required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DailyGrind"
BUNDLE_ID="com.harsha.dailygrind"
SRC_APP="$ROOT/$APP_NAME.app"

if [ ! -d "$SRC_APP" ]; then
  echo "Error: $SRC_APP not found. Run this script from inside the extracted zip." >&2
  exit 1
fi

echo "Installing $APP_NAME.app to /Applications..."
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 0.5
rm -rf "/Applications/$APP_NAME.app"
cp -R "$SRC_APP" "/Applications/$APP_NAME.app"

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
echo ""
echo "NOTE: since this app isn't notarized by Apple, macOS Gatekeeper may"
echo "block it the first time. If so: open /Applications in Finder,"
echo "right-click DailyGrind.app -> Open -> confirm."

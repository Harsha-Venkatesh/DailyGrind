# Daily Grind

A tiny always-on-top macOS widget that nags you to hit daily job-search goals:

- 💼 Jobs Applied — counter, target 10
- 🧩 LeetCode — counter, target 3
- 🍽️ Log food / 📚 Interview prep / 🏋️ Workout — checkboxes

Floats above every app (including fullscreen apps and other Spaces), is
frameless and draggable, resets automatically at midnight, archives each
finished day to a history file, and auto-hides itself once all 5 items are
done for the day. A menu bar icon (🎯) stays running in the background so you
can reopen the widget or view stats at any time.

## Requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)

## Install

```bash
./scripts/install.sh
```

This builds the app, packages it as `DailyGrind.app`, installs it to
`/Applications`, and registers a LaunchAgent so it starts automatically at
login.

## Manual build (without installing)

```bash
swift build -c release
.build/release/JobGrindWidget
```

## Data

- Today's live counts: `UserDefaults` under `com.harsha.dailygrind`
- Daily history: `~/Library/Application Support/DailyGrind/history.json`
- CSV export: available from the Stats window ("Export CSV to Desktop")

## Uninstall

```bash
launchctl bootout gui/$(id -u)/com.harsha.dailygrind
rm ~/Library/LaunchAgents/com.harsha.dailygrind.plist
rm -rf /Applications/DailyGrind.app
```

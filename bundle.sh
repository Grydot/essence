#!/bin/bash
# Builds Essence and assembles Essence.app from existing project files
# (Info.plist + Essence.icns). All bundle metadata lives in Info.plist —
# this script just compiles and copies; it doesn't generate any plist itself.
set -e

CONFIG="release"
PLIST="Info.plist"
ICON="Essence.icns"

[ -f "$PLIST" ] || { echo "error: $PLIST not found" >&2; exit 1; }

# Single source of truth: derive names from Info.plist.
PB=/usr/libexec/PlistBuddy
BIN_NAME=$("$PB" -c "Print :CFBundleExecutable" "$PLIST")
APP_NAME=$("$PB" -c "Print :CFBundleName" "$PLIST")
APP="${APP_NAME}.app"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$BIN_NAME"
[ -f "$BIN_PATH" ] || { echo "error: built binary not found at $BIN_PATH" >&2; exit 1; }

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN_NAME"
cp "$PLIST"    "$APP/Contents/Info.plist"
[ -f "$ICON" ] && cp "$ICON" "$APP/Contents/Resources/$ICON"

# Ad-hoc sign so Keychain access and window behaviour are consistent.
codesign --force --deep --sign - "$APP" 2>/dev/null || \
    echo "note: codesign skipped (optional, but recommended)"

echo "==> done: $APP"

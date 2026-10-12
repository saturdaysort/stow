#!/bin/zsh
# Builds Stow in release mode and assembles an unsigned app bundle. install.sh (dev loop)
# and release.sh (shareable build) both call this, so they ship the same bundle.
# Prints only the app's path on stdout; build output goes to stderr.
# Usage: APP="$(scripts/build-app.sh)"
set -euo pipefail
cd "${0:A:h}/.."

APP="build/Stow.app"

echo "Building release..." >&2
swift build -c release --product Stow >&2
BIN_DIR="$(swift build -c release --product Stow --show-bin-path)"

echo "Assembling $APP..." >&2
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Stow" "$APP/Contents/MacOS/Stow"
# The build number is the commit count, so every build of one commit carries the same number.
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
sed "s/__BUILD_NUMBER__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint -s "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

print -r -- "$APP"

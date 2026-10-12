#!/bin/zsh
# Builds Stow, signs it with your Apple Development identity, installs it to
# /Applications and relaunches it. Exam mode only recognizes the installed copy,
# so this is the dev loop (spec 6.7). Usage: scripts/install.sh
set -euo pipefail
# awk reads whole streams below (no early `exit`): an early exit closes the pipe, and under
# pipefail the writer's SIGPIPE (exit 141) would abort the script.
cd "${0:A:h}/.."

APP="build/Stow.app"
INSTALLED="/Applications/Stow.app"

echo "Building release..."
swift build -c release --product Stow
BIN_DIR="$(swift build -c release --product Stow --show-bin-path)"

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Stow" "$APP/Contents/MacOS/Stow"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
sed "s/__BUILD_NUMBER__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
plutil -lint -s "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# A stable identity keeps the Accessibility grant across rebuilds; ad-hoc signing resets it every time.
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development:/ && !found { print $2; found = 1 }')"
if [[ -z "$IDENTITY" ]]; then
  echo "No 'Apple Development' signing identity in your keychain. Add one in Xcode > Settings > Accounts." >&2
  exit 1
fi
echo "Signing with: $IDENTITY"
codesign --force --sign "$IDENTITY" --timestamp=none "$APP"

# Quit the running copy first so it releases its exam-mode assertion (SIGTERM is routed to a clean quit).
if pgrep -x Stow >/dev/null; then
  echo "Quitting the running Stow..."
  pkill -TERM -x Stow || true
  for _ in {1..50}; do pgrep -x Stow >/dev/null || break; sleep 0.1; done
  if pgrep -x Stow >/dev/null; then
    echo "Stow didn't quit within 5 seconds; stopping here." >&2
    exit 1
  fi
fi

echo "Installing to $INSTALLED..."
rm -rf "$INSTALLED"
ditto "$APP" "$INSTALLED"
# Right after the old copy quits, LaunchServices can still be tearing it down and `open`
# fails with error -600. Retry briefly; the running-process check below has the final say.
for _ in {1..10}; do open "$INSTALLED" 2>/dev/null && break; sleep 0.5; done

# A build isn't an install: verify what's installed and what's actually running.
codesign --verify --strict "$INSTALLED"
AUTHORITY="$(codesign -dvv "$INSTALLED" 2>&1 | awk -F= '/^Authority=/ && !found { print $2; found = 1 }')"
if [[ "$AUTHORITY" != Apple\ Development:* ]]; then
  echo "Unexpected signing authority: '$AUTHORITY'" >&2
  exit 1
fi
for _ in {1..50}; do pgrep -f "^$INSTALLED/Contents/MacOS/Stow" >/dev/null && break; sleep 0.1; done
if ! pgrep -f "^$INSTALLED/Contents/MacOS/Stow" >/dev/null; then
  echo "Stow isn't running from $INSTALLED." >&2
  exit 1
fi
VERSION="$(defaults read "$INSTALLED/Contents/Info" CFBundleShortVersionString)"
echo "Installed Stow $VERSION (build $BUILD_NUMBER), signed by $AUTHORITY, running from $INSTALLED."

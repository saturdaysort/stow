#!/bin/zsh
# Builds a Stow anyone on macOS 27 can install: signed with your Developer ID, notarized by
# Apple, with the notarization ticket stapled inside the app, then zipped. See docs/releasing.md.
# Usage: scripts/release.sh             build and verify build/release/Stow-<version>.zip
#        scripts/release.sh --publish   then tag v<version> and attach the zip to a GitHub Release
set -euo pipefail
# awk reads whole streams below (no early `exit`); see install.sh for the SIGPIPE reason.
cd "${0:A:h}/.."

case "${1:-}" in
  "") PUBLISH=false ;;
  --publish) PUBLISH=true ;;
  *) echo "Usage: scripts/release.sh [--publish]" >&2; exit 2 ;;
esac

NOTARY_PROFILE="stow-notary"   # stored once with `xcrun notarytool store-credentials` (docs/releasing.md)
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
TAG="v$VERSION"
OUT="build/release"
ZIP="$OUT/Stow-$VERSION.zip"

fail() { echo "$1" >&2; exit 1; }

# A release comes from a committed tree, so its build number and tag name exactly what shipped.
[[ -z "$(git status --porcelain)" ]] || fail "Commit your changes first; a release is built from a clean tree."
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  fail "Tag $TAG already exists. Bump CFBundleShortVersionString in Resources/Info.plist first."
fi

# Only a Developer ID Application certificate works here. "Mac Installer Distribution" (listed as
# "3rd Party Mac Developer Installer") signs App Store .pkg uploads; "Apple Development" is install.sh's.
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ && !found { print $2; found = 1 }')"
[[ -n "$IDENTITY" ]] \
  || fail "No 'Developer ID Application' identity in your keychain. Create one in Xcode > Settings > Accounts > Manage Certificates (docs/releasing.md)."
# Show notarytool's own words: "missing credentials" and "network down" need different fixes.
if ! NOTARY_ERROR="$(xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" 2>&1 >/dev/null)"; then
  fail "The notary credentials '$NOTARY_PROFILE' didn't work. notarytool said:"$'\n'"$NOTARY_ERROR"$'\n'"If they're missing, store them again (docs/releasing.md)."
fi

APP="$(scripts/build-app.sh)"

echo "Signing with: $IDENTITY"
# Notarization requires the hardened runtime and a secure timestamp.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
DETAILS="$(codesign -dvv "$APP" 2>&1)"
[[ "$DETAILS" == *"Authority=Developer ID Application:"* && "$DETAILS" == *"(runtime)"* ]] \
  || fail "The signature isn't Developer ID with the hardened runtime:"$'\n'"$DETAILS"

rm -rf "$OUT"
mkdir -p "$OUT"
SUBMISSION="$OUT/Stow-notarize.zip"
ditto -c -k --keepParent "$APP" "$SUBMISSION"
echo "Submitting to Apple's notary service (usually a few minutes)..."
RESULT="$(xcrun notarytool submit "$SUBMISSION" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)" || true
STATUS="$(print -r -- "$RESULT" | plutil -extract status raw -o - - 2>/dev/null)" || STATUS=""
if [[ "$STATUS" != "Accepted" ]]; then
  echo "Notarization status: ${STATUS:-unknown}" >&2
  SUBMISSION_ID="$(print -r -- "$RESULT" | plutil -extract id raw -o - - 2>/dev/null)" || SUBMISSION_ID=""
  if [[ -n "$SUBMISSION_ID" ]]; then
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" >&2 || true
  else
    print -r -- "$RESULT" >&2
  fi
  exit 1
fi
rm -f "$SUBMISSION"

# The ticket goes inside the app, not just next to it, so Stow opens even if its first launch is offline.
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{ print $1 }')"

# Check what ships, not what was built: unzip it the way a recipient would and ask Gatekeeper.
CHECK="$(mktemp -d)"
ditto -x -k "$ZIP" "$CHECK"
xcrun stapler validate "$CHECK/Stow.app"
codesign --verify --strict --deep "$CHECK/Stow.app"
ASSESSMENT="$(spctl --assess --type execute -vv "$CHECK/Stow.app" 2>&1)" || true
rm -rf "$CHECK"
[[ "$ASSESSMENT" == *"source=Notarized Developer ID"* ]] \
  || fail "Gatekeeper didn't accept the zipped app:"$'\n'"$ASSESSMENT"
echo "Built $ZIP (sha256 $SHA). Gatekeeper accepts it as Notarized Developer ID."

if [[ "$PUBLISH" != true ]]; then
  echo "Not published. Try build/Stow.app from /Applications first, then run: scripts/release.sh --publish"
  exit 0
fi

# Commit and push are separate steps: this only publishes a commit GitHub already has.
git fetch -q origin
git merge-base --is-ancestor HEAD origin/main || fail "Push main first; $TAG has to point at a commit GitHub already has."
[[ -z "$(git ls-remote --tags origin "refs/tags/$TAG")" ]] || fail "Tag $TAG already exists on GitHub."
# The release page's text and screenshots live in docs/release-notes.md.
NOTES="$OUT/release-notes.md"
sed "s/__VERSION__/$VERSION/g" docs/release-notes.md > "$NOTES"
git tag -a "$TAG" -m "Stow $VERSION"
git push -q origin "$TAG"
gh release create "$TAG" "$ZIP" --verify-tag --title "Stow $VERSION" --notes-file "$NOTES"

# A push isn't a release: download what GitHub serves and compare it with what was built.
DOWNLOAD="$(mktemp -d)"
gh release download "$TAG" --pattern "Stow-$VERSION.zip" --dir "$DOWNLOAD"
SERVED="$(shasum -a 256 "$DOWNLOAD/Stow-$VERSION.zip" | awk '{ print $1 }')"
rm -rf "$DOWNLOAD"
[[ "$SERVED" == "$SHA" ]] || fail "GitHub serves a different file (sha256 $SERVED, built $SHA)."
echo "Published $TAG: $(gh release view "$TAG" --json url --jq .url)"

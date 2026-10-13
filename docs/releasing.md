# Releasing Stow

A release is a zip of `Stow.app` that anyone on macOS 27 can download, unzip, drag to Applications and open with no security warning. macOS needs three things for that: a Developer ID signature, notarization by Apple, and the notarization ticket stapled inside the app. `scripts/release.sh` does all three, then checks the zip the way a recipient's Mac will.

## One-time setup

1. **Create a Developer ID Application certificate.** In Xcode, go to Settings › Accounts, select your team, then Manage Certificates › + › Developer ID Application. Only the account holder can create one.
   - **Not "Mac Installer Distribution"**, which the keychain lists as "3rd Party Mac Developer Installer". That one only signs `.pkg` uploads to the Mac App Store.
   - **Not "Apple Development".** That's for builds on your own Mac, from `scripts/install.sh`.
2. **Store notary credentials in your keychain** under the name `stow-notary`:
   - Create an app-specific password at account.apple.com › Sign-In and Security › App-Specific Passwords.
   - Run this in a terminal window, with your Apple ID in place of `you@example.com`. Paste the app-specific password when it asks. The password lives in your keychain, never in this repo.
   - Run it in a real terminal, not through Claude's `!` prefix, because it prompts for the password and `!` output lands in the chat. Don't wrap the email in angle brackets: zsh reads `<` as a file to take input from.

   ```bash
   xcrun notarytool store-credentials stow-notary --apple-id you@example.com --team-id YJM6S6FCW4
   ```

## Cut a release

1. **Set the version** in `Resources/Info.plist` (`CFBundleShortVersionString`) and commit. `scripts/build-app.sh` sets the build number to the commit count.
2. **Build it:** `scripts/release.sh`. It builds Stow, signs it, notarizes it and staples the ticket. Then it writes `build/release/Stow-<version>.zip` and confirms Gatekeeper accepts the unzipped app as "Notarized Developer ID".
3. **Try it on your own Mac.** Quit Stow, copy `build/Stow.app` to `/Applications`, open it, and check that hiding works on every display.
4. **Publish:** push `main`, then run `scripts/release.sh --publish`. It rebuilds from the same commit and tags it `v<version>`. Then it attaches the zip to a GitHub Release, downloads it back, and compares checksums.

## Traps

- **Accessibility is granted per signature.** To macOS, a release build (Developer ID) and a dev build (Apple Development) are different apps. Switching between them means granting Accessibility again.
- **The ticket is stapled to the app, not just the zip.** So Stow opens even if its first launch happens offline.
- **The repo is private.** A GitHub Release there is only visible to people with access to the repo.
- **Store the notary credentials from the Terminal app.**
  - On 2026-10-12, credentials stored from the terminal tab inside the Claude desktop app notarized a build at 17:00. By 18:50 notarytool reported "No Keychain password item found", and the system log showed no cause.
  - Storing them again from the Terminal app worked for the next release.
  - If `release.sh` reports that error, run `store-credentials` again from the Terminal app.
- **If `--publish` fails after pushing the tag, don't rerun it.** It will stop, because the tag already exists.
  - On 2026-10-12, GitHub's upload server timed out. That left a draft release with no file attached.
  - To finish by hand, attach the zip that `release.sh` built to the draft, then publish the draft:

  ```bash
  VERSION=0.1.0
  RELEASE_ID="$(gh api repos/saturdaysort/stow/releases --jq '.[] | select(.draft) | .id')"
  gh api --method POST -H "Content-Type: application/zip" "https://uploads.github.com/repos/saturdaysort/stow/releases/$RELEASE_ID/assets?name=Stow-$VERSION.zip" --input "build/release/Stow-$VERSION.zip"
  gh api --method PATCH "repos/saturdaysort/stow/releases/$RELEASE_ID" -F draft=false
  ```

  - Then download the zip with `gh release download` and check that its `shasum -a 256` matches the build.
- **`--publish` rebuilds and re-notarizes** rather than reusing step 2's zip. That costs a few minutes, but the published file is always built from the tagged commit.

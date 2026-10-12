# Stow on-device verification

- **Date:** 2026-10-12
- **macOS:** 27.2 (26B5101f)
- **Stow:** 0.1.0, builds 16 to 19. Checks after the review fixes ran on builds 18–19.
- **Displays:**
  - Built-in Retina at 1800×1169pt (notched). Some checks ran at 1512×982 while scaling was changed mid-session.
  - Studio Display at 2880×1620pt.
- **Hide list during the checks:** Claude, TextInputMenuAgent (keyboard menu), Tiny Ipsum, Voicenotes, Tailscale, Nightfall. Re-hide delay 5 seconds.

Evidence is the `screencapture -R` menu bar images in `build/verification/`. That folder is git-ignored and stays local.

| # | Check (spec 7.2) | Result | Evidence |
|---|---|---|---|
| 1 | Hide and show on both displays; right-click menu | **Pass.** A left-click reveals all six apps on both displays and auto re-hide fires after 5s. Nate confirmed the right-click menu's items. | `check1c/066,068,076`, `twodisplay/015,017` |
| 2 | An app launched while hidden stays visible; flicker | **Failed on build 16, pass after fix `b314a36`.** Tiny Ipsum (an agent app), launched while hidden, appeared within seconds while the others stayed hidden. No flicker: changes were one icon wide, with no frame where everything reappeared. | `2b-before-launch`, `2b-after-launch`, `check2tiny` |
| 3 | Crash test (release gate) | **Pass.** After `kill -9` while hidden, every hidden icon returned within 3s on its own. | `3-before-crash`, `3-after-crash` |
| 4 | Side effects while hidden | **Measured.** See "Exam-mode side effects" below; the Settings footnote and README now say so (`5f7769c`). | `1-click-sequence`, `4-wide-range-hidden` |
| 5 | Sleep/wake, display unplug/replug, logout/login | **Pass.** Sleep/wake and unplug/replug pass. A full restart passes too, with permissions reset beforehand. See "Restart and login" below. | `5-after-wake-*`, `5-after-replug-*`, `login-before-*`, `login-after/` |
| 6 | Only Accessibility requested; grant survives installs | **Pass.** See "Permissions from scratch" below. | `build/verification/tcc-full.log` |
| 7 | Copy outside /Applications refuses to hide | **Pass.** `build/Stow.app` showed a dimmed drawer and hid nothing. | `7-offsite` |
| 8 | Amber shade on dark and light bars | **Pass for shade selection; light-bar contrast below target.** See "Amber, measured" below. | `check8light3`, `check1c/068` |

## Exam-mode side effects (check 4)

- **Hidden while Stow hides:**
  - the Focus icon;
  - the microphone/camera in-use indicator (the orange mic pill, MenuBarAgent's AudioVideoModule).
- **Stays visible:** the small orange privacy dot at the far right.
- **Clicking the clock while hidden** does not open Notification Center (Nate confirmed).
- **Not tested:** Now Playing, because nothing was playing. Upstream reports say it hides.
- **A wider system-item range** (`0..<256` instead of `0..<64`) changed nothing on device, so it was reverted.
- **Quitting brings everything back:** via the menu, via SIGTERM, and via `kill -9`.

## Restart and login (check 5)

- **Setup:** Nate reset Stow's permissions with `tccutil reset All studio.longbrook.stow`, then restarted the Mac. It booted at 15:34:25 and Nate logged in at 15:34:59.
- **Result:** Stow started on its own at 15:35:18 from `/Applications`, with no permissions, and hid the chosen apps. Nate reported everything running as expected.
- **Launch order:** MenuBarAgent's log shows menu bar apps registering at login:
  - Tailscale at 15:35:00, Claude at :01, Control Center at :02, Voicenotes at :04 and Granola at :09;
  - Teams and Stow at 15:35:18;
  - Tiny Ipsum and Nightfall at 15:35:19.

  So Stow's first hide overlapped other launches. That's the window where deferred minor #7 applies, and Teams, which isn't on the hide list, launched inside it.
- **Measured end state:** at 15:38, launching Calculator, which has no menu bar icon, made Stow rebuild its allow-list. Both menu bars were pixel-identical before and after: 0 changed pixels in each of 5 frames. Nothing was wrongly hidden by then. This shows the end state, not the rebuild itself; check 2 already showed the launch watcher reacting.

## Permissions from scratch (check 6)

1. Nate ran `tccutil reset All studio.longbrook.stow` themselves. Stow then **hid icons with no permissions at all**, because hiding never needs Accessibility.
2. Settings showed the Accessibility banner. After the grant, the list filled in without a relaunch.
3. A newly recorded ⌃⌥J shortcut worked system-wide. The shortcut is back to ⌃⌥H.
4. Stow is **not** listed under Screen & System Audio Recording or Input Monitoring.
5. **TCC log** (`/usr/bin/log show --info --debug`, filtered by Stow's PID):
   - Stow's own requests were all `kTCCServiceAccessibility`: 64, from Settings polling while the banner showed.
   - There was one `kTCCServiceListenEvent` check, sent by **WindowServer** with Stow as the target. WindowServer sent the same check for MenuBarAgent and other processes. It prompted nothing, and the shortcut works without it.
6. The Accessibility grant **survived three reinstalls**, because of the stable Apple Development signature.

**Two traps found here:**
- In a non-interactive zsh, `log` is zsh's built-in, not `/usr/bin/log`.
- Without `--info --debug`, `log show` hides these TCC lines.

## Amber, measured (check 8)

| Menu bar | Bar color | Stow draws | macOS renders | Contrast |
|---|---|---|---|---|
| Dark (Nate's wallpaper) | #626060 | #FFB340 | #F7C169 | **3.80:1** (target ≥ 3) |
| Light (light-blue wallpaper) | #97D5FA | #A35400 | #AA6B27 | **2.73:1** (below 3) |

- **Shade selection is correct:** the status button's appearance follows the bar (open question 4: yes). With the bright amber, the light bar would have measured 1.03:1.
- **macOS 27 lightens colored status icons** by about 15%, and real bars are translucent mid-tones. That's why measured contrast sits well under the design figures (9.35 and 4.52 against the reference bars).
- **Design decision for Nate:** a darker light-bar amber, around #8A4700, would clear 3:1 even on mid-light bars.
- **The wallpaper decides** whether the macOS 27 menu bar is light or dark. Switching Appearance to Light alone did not change it.

## Notarized release build

Checked 2026-10-12 with `build/release/Stow-0.1.0.zip` (build 24), unzipped and installed the way a recipient would.

- **Signature:** Developer ID Application, with the hardened runtime that notarization requires. Gatekeeper accepts the installed app as "Notarized Developer ID", and its stapled ticket validates.
- **Hiding still works under the hardened runtime:**
  - **Launched:** on both displays, exactly the six chosen apps hid. Stow's own drawer stayed visible, so macOS still matches Stow by its bundle ID under the new signature.
  - **After a clean quit:** all six came back.
  - **Relaunched:** both menu bars were pixel-identical to the first launch.
  - **Against the dev build:** on the Studio Display, the hidden menu bar was pixel-identical to the dev build's after the restart (check 5).

Evidence: `rel-hidden/`, `rel-quit/` and `rel-hidden2/`.

## Open questions (spec section 9)

1. **Force-quit releases the assertion:** **yes** (check 3). MenuBarAgent drops it when the process dies.
2. **Camera/mic indicator while hidden:** **hidden**, and a wider `allowedSystemItems` range doesn't help.
3. **Hidden apps in `AXExtrasMenuBar` while hidden:** not measured directly. The Settings list always includes hidden apps from the hide list, so it's covered either way.
4. **Status button appearance follows the menu bar:** **yes** (deep amber on the light bar, bright on the dark bar).
5. **Menu Bar settings link:** `x-apple.systempreferences:com.apple.ControlCenter-Settings.extension` opens the **Menu Bar pane** (Nate confirmed).
6. **Pop-up menu detection for auto re-hide:** **works.** Icons stayed up while another app's menu was open and re-hid after it closed.
7. **Flicker when swapping lists:** **none observed** at about 0.6s sampling (hide-list change and app launch).

## Changes made because of these checks and the review

- **`b314a36` review fixes:**
  - **Launch watcher:** apps are now watched through KVO on `NSWorkspace.runningApplications`. AppKit doesn't post `didLaunchApplicationNotification` for agent (LSUIElement) or background apps, as its documentation says, which is why check 2 failed on build 16.
  - **No needless swaps:** an unchanged allow-list no longer swaps assertions.
  - **Fail-safe on an emptied list:** a list emptied outside Stow now releases the assertion.
  - **No crash on a damaged modifier mask:** an oversized mask now falls back to ⌃⌥H instead of trapping.
  - **Settings refresh:** the list refreshes when the window becomes key, and on app launch or quit while it's visible.
- **`5f7769c`:** the Settings footnote and the README now mention the mic/camera indicators.
- **`0add41c`:** `install.sh` retries `open`. Right after the old copy quits, LaunchServices can return `-600`.
- **Task 15:** `install.sh` reads whole `awk` streams. An early `exit` caused SIGPIPE under `pipefail`.

## Known limits recorded here

- **Hiding is per app,** so all of an app's icons hide together.
- **Apps macOS can't match by bundle ID always hide** while Stow hides. That includes ad-hoc-signed apps run from outside the usual locations (the throwaway probe app stayed hidden even when allowed) and tools without a bundle ID.
- **Shortcut conflicts can't be detected.** Carbon only reports duplicates within Stow itself, and combinations like ⌘Q can be recorded. (Review finding 8, kept for v1.)

## Minor issues deferred from the code review

The whole-branch review graded these Minor, and they were left for later.

- **#7 Launches during the first hide:** an app that launches while Stow's first hide is still in flight isn't re-allowed until the next launch. At login, the burst of launches usually covers it (check 5).
- **#9 No logging:** a failed swap, the hot-key handler's install status and a first-run login item error go unrecorded.
- **#10 Only Stow on the list:** a hide list holding only Stow's own ID turns exam mode on with nothing to hide.
- **#11 Empty list at launch:** the launch checks (spec 4.6) don't run, so the menu says "Pick apps" instead of showing Unavailable.
- **#12 Unavailable menu wording:** it shows a disabled "Show Hidden Icons", where "Hide Icons" would read better.
- **#13 Dead keys:** `kUCKeyTranslateNoDeadKeysBit` is passed as 0 instead of the mask 1, which affects dead-key names in the shortcut display.
- **#14 No main menu:** ⌘W and ⌘Q don't work while Settings is frontmost.
- **#15 Bridge cleanup:**
  - an assertion that fails to activate is released without `invalidate`;
  - if the completion never arrives, there's no handle to release it.
- **#16 Signing:**
  - `install.sh` signs by identity name, which becomes ambiguous after a certificate renewal;
  - its authority check only matches a prefix.
- **#17 Vacuous test:** `scanWithoutAccessibility` proves nothing when the test runner itself has Accessibility.

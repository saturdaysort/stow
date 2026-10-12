# macOS 27 menu bar: what changed, what we measured

Measured 2026-10-12 on macOS 27.2 beta (build 26B5101f), Xcode 27.0 / Swift 6.4, with a MacBook built-in display (1800×1169pt, notch spanning x 790–1010) and a Studio Display (2880×1620pt). Read this before changing how Stow hides icons. Every rejected approach below was tried for real, and the numbers explain why it failed.

## Summary

- On macOS 27, **exam mode** is the only way for a third-party app to hide other apps' menu bar icons on demand. It's a private allow-list in `MenuBarClientCore`, and it is what Stow uses.
- The classic trick of **stretching a divider status item** no longer works. macOS ejects an over-long item, and one length can't serve two displays.
- The **System Settings "Allow in the Menu Bar" switches** can be read and written through a one-file grant, but a direct write doesn't take effect live.

## What changed in macOS 27

- **`MenuBarAgent` draws every status item.** It lives at `/System/Library/CoreServices/MenuBarAgent.app` and registers the FrontBoard workspace `com.apple.appkit.status-items`.
- **`CGWindowListCopyWindowInfo` no longer shows per-item windows.** Each display has one full-width `Menubar` window owned by Window Server (layer 24). Anything that finds icons through window lists is broken, which includes Ice and Dozer.
- **Each display's menu bar is laid out independently.** One `NSStatusItem.length` still applies to all of them.
- **There's a native overflow control («).** Items that don't fit move into it, leftmost first. On the notched display, the usable edge sits about 70pt right of the notch, not at the notch.
- **The only new status item API is for popovers:** `NSStatusItem.expandedInterfaceDelegate` and `NSStatusItemExpandedInterfaceSession` (MacOSX27.0.sdk `NSStatusItem.h`). Nothing public hides other apps' items.
- **`com.apple.MenuBarAgent` → `TrailingItemPreferredPositions` is not a layout source.**
  - Keys look like `status:<bundle id or app name>::<autosaveName>`, with system items as `module:<name>`.
  - Entries appear only after a user ⌘-drags an item, and the values don't match the on-screen order.
  - Apps no longer get `NSStatusItem Preferred Position` keys in their own defaults.
- **New status items appear at the far left** of the status area, and a newer item lands left of older ones.
- **`button.window.frame` only describes the active display.** An app's own status item frame is accurate for whichever display is active and says nothing about the others.

## Why Hidden Bar 1.8 broke

Hidden Bar hides by setting a divider status item's length to 10,000pt, so that everything to its left falls off the screen. On 27, MenuBarAgent ejects an item that long from the layout instead. The divider disappears and nothing hides (upstream issue dwarvesf/hidden#360). Upstream fixed this in v1.11.1 (2026-09-18, GitHub download only) by switching to exam mode. The App Store listing is still v1.8 from 2021.

## Probe 1: a divider sized to fit (rejected)

The appeal was that it uses only public APIs and needs no permissions. The test app had a divider (`SEP`) with three dummy items to its left, and every step was captured on both menu bars with `screencapture -R`.

| Divider length | Built-in (notched, 1800pt) | Studio Display (2880pt) |
|---|---|---|
| 34–90pt | Fits. Dummies overflow into « as space runs out | Fits. Dummies visible |
| 90–120pt | Divider stays; **all dummies in «** (real hiding) | Dummies visible, just shifted left |
| 200–400pt | Divider itself goes into « | Dummies visible |
| 700pt | Everything left of the divider vanishes, no « | Dummies visible |
| 1000–1300pt | Divider ejected, dummies come back | Dummies still visible |
| 1600pt+ | Divider ejected | **Divider ejected** before it ever pushed anything out |

**Conclusion:** no single length hides icons on both displays. On the Studio Display, no length hides anything. The behavior also isn't monotonic and may depend on hidden state, so this route is dead.

## Probe 2: the "Allow in the Menu Bar" switches (rejected as a toggle)

**The file:** `~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist`. The shell is blocked from it ("Operation not permitted"). An unsandboxed app gets read and write access to that one file when the user picks it in an `NSOpenPanel` (Thaw's method).

**Format:**
- Outer keys are `trackedApplications`, `remoteLiveActivityApplications`, `showSiri` and `showSpotlight`.
- `trackedApplications` is a nested binary plist. It's a Swift `Codable` dictionary encoded as an alternating `[key, value, …]` array:
  - key: `{"bundle": {"_0": "<bundle id>"}}` or `{"adhocBinary": {"_0": {"relative": "file:///…"}}}`
  - value: `{isAllowed, location, menuItemLocations}`
- `isAllowed` is the System Settings switch. Turning off Tailscale flipped exactly `io.tailscale.ipn.macos` to false.

**Side effect of opening the pane:** System Settings › Menu Bar rewrites the list and drops apps that aren't present (30 entries became 20). One of the dropped apps had `isAllowed = false`, so a "hidden" choice can be silently forgotten.

**The result:** writing `isAllowed = true` straight to the file did **not** bring the icon back (checked at 1, 3 and 6 seconds), even though the file kept the new value. The live value sits in `cfprefsd`/MenuBarAgent, which only hear about changes that come through System Settings. Forcing a reload would mean killing `cfprefsd` or Control Center, which is unacceptable for a toggle. Thaw keeps its reload trigger in a closed-source binary.

## Exam mode (what Stow uses)

- **Framework:** `/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore`, loaded at run time with `dlopen`.
- **Calls:** `[[MBAssessmentModeConfiguration alloc] initWithAllowedSystemItems:allowedBundleIdentifiers:]`, then `[[MBAssessmentModeAssertion alloc] init]`, then `activateWithConfiguration:completionHandler:`. `invalidate` releases it.
- **Both lists must be `NSArray`.** The framework indexes into them, so an `NSSet` raises `-objectAtIndex:`.
- **Upstream passes system items `0..<64`** to keep macOS's own items.
- **It's an allow-list.** Anything not listed hides, including the app's own icon, so the app must include its own bundle ID.
- **Requirements:** unsandboxed, and running from `/Applications`. A copy elsewhere hides its own icon.
- **Reported side effects while active** (dwarvesf/hidden #410, #412, #414, #421, #424, #432, #435, #436, #437, #444, #446):
  - clicking the clock doesn't open Notification Center;
  - Focus and Now Playing hide whatever the list says;
  - the mic/camera in-use indicator reportedly hides;
  - it's per app only.
- **Verified on this machine** (see "Measured during Stow's verification" below): a crash releases the assertion, the mic/camera indicator does hide, and swapping one assertion for another doesn't flicker.

The API usage was learned from dwarvesf/hidden (MIT), `HBNativeVisibilityShim.m`. Stow's bridge is a fresh implementation of the same calls.

## Measured during Stow's verification

Measured 2026-10-12 with Stow builds 16–19 on both displays. Per-check results are in `docs/verification.md`.

- **Launch notifications skip agent apps.** AppKit doesn't post `NSWorkspace.didLaunchApplicationNotification` for agent (LSUIElement) or background apps, which covers most menu bar apps. This is documented behavior, not something new in 27. Apple's docs point to KVO on `NSWorkspace.shared.runningApplications`, which sees every launch and quit. Stow's first build relied on the notification, so an agent app launched while icons were hidden stayed hidden.
- **A crash releases the assertion.** After `kill -9` while hidden, every icon came back within 3 seconds with no help. Quitting from the menu and SIGTERM bring them back too.
- **Exam mode hides more than the list.** While it's active, the Focus icon and the mic/camera in-use pill (MenuBarAgent's `AudioVideoModule`) hide, and clicking the clock doesn't open Notification Center. The small orange privacy dot at the far right stays. Widening `allowedSystemItems` from `0..<64` to `0..<256` changed nothing.
- **Swapping assertions doesn't flicker** when the new one activates before the old one is invalidated. Frames sampled about every 0.6 seconds showed only the affected icon change.
- **Ad-hoc-signed probe apps are poor test subjects.** A throwaway app, ad-hoc signed and run from `/private/tmp`, stayed hidden even with its bundle ID on the allow-list. Which of the two caused it wasn't isolated, but the Control Center plist keys ad-hoc apps by file URL (`adhocBinary`), which fits. A signed agent app (Tiny Ipsum) behaved as expected.
- **The wallpaper decides whether the menu bar is light or dark,** not the Appearance setting. With Appearance set to Light over a dark wallpaper, the bar stayed grey with white text. A status button's `effectiveAppearance` follows the bar, so it's the right value to pick colors from.
- **Colored status icons render lighter and less saturated than drawn.** Stow's `#FFB340` renders as `#F7C169`, and `#A35400` as `#AA6B27`. Over real, translucent bars, contrast measured 3.80:1 on a dark bar (`#626060`) and 2.73:1 on a light-blue one (`#97D5FA`), where the design math against reference bars gave 9.35 and 4.52. Measure rendered pixels against the real bar.
- **`CGWindowList` still shows open pop-up menus** at the pop-up menu window level. Reading levels and bounds needs no Screen Recording, so auto re-hide can wait while a menu is open.
- **The Menu Bar settings link works:** `x-apple.systempreferences:com.apple.ControlCenter-Settings.extension` opens System Settings › Menu Bar.
- **Carbon can't see other apps' hot keys.** `RegisterEventHotKey` only reports a clash within the same process, so Stow can't warn that another app already uses a shortcut.

## Other traps

- **Ad-hoc signing changes the code identity every build**, so macOS forgets the Accessibility grant. Sign with a stable Apple Development identity. With one, Stow's grant survived three reinstalls.
- **Option-clicks can't be read from `currentEvent`.** On 27, `NSApp.currentEvent.modifierFlags` is reportedly empty inside a status item's action (dwarvesf/hidden#434). Read the event type, or use `NSEvent.modifierFlags`.
- **Screen capture works from this dev environment** with `screencapture -x -R x,y,w,h` (global coordinates with a top-left origin). It's the reliable way to check what the menu bar really shows. Stow itself never needs Screen Recording. Re-read display rects after a scaling change or an unplug, or the capture lands on the wrong strip.
- **TCC requests only show with the real `log` and extra levels.** In a non-interactive zsh, `log` is a zsh built-in, so call `/usr/bin/log show --info --debug`. WindowServer runs a `kTCCServiceListenEvent` check against many processes, Stow included. That isn't Stow asking, and nothing prompts.
- **`open` can fail with error -600 right after the old copy quits,** while LaunchServices catches up. `scripts/install.sh` retries for up to 5 seconds.

## Sources

- dwarvesf/hidden (MIT): v1.11.1 source (`HBNativeVisibilityShim.m`, `NativeVisibilityEngine.swift`, `CHANGELOG.md`, `docs/MANUAL.md`); issues #360, #397, #403, #434, #437 and those listed above.
- thaw-app/Thaw 3.0.0-beta.2 (GPL-3.0): `PickedFileAccess.swift`, read for facts only. No code copied.
- Apple MacOSX27.0.sdk headers: `NSStatusItem.h`, `NSStatusItemExpandedInterfaceSession.h`.
- Probe apps and screenshots from 2026-10-12. They were throwaway and are not in this repo.

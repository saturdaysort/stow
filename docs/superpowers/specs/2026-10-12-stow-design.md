# Stow — design spec

- **Date:** 2026-10-12
- **Status:** draft for review
- **Owner:** Nate
- **Background:** [`docs/macos-27-menu-bar-findings.md`](../../macos-27-menu-bar-findings.md) explains why the design looks like this. Read it first.

## 1. Summary

Stow is a personal macOS 27 menu bar utility that hides the menu bar icons of apps you choose behind one toggle. It replaces Hidden Bar, whose App Store build stopped hiding anything on macOS 27.

Stow hides apps using macOS's private exam-mode allow-list, the only mechanism that works on 27. You pick which apps to hide from a list in a System Settings–style window. A drawer icon in the menu bar shows whether icons are hidden (closed) or showing (open, amber).

## 2. Goals and non-goals

**Goals**
- One click or shortcut hides or shows the chosen apps' menu bar icons.
- You choose the apps from a list of apps that have menu bar icons.
- Auto re-hide after a delay, a global keyboard shortcut, and launch at login.
- A link to System Settings for apps you want hidden for good.
- Honest about exam mode's side effects. Fails safe, so icons are never stranded hidden.

**Non-goals**
- Per-icon hiding (exam mode works per app).
- App Store distribution, notarization, or sharing with other people.
- macOS 26 or earlier.
- Reveal on hover.
- A separate bar or panel showing pictures of hidden icons, which would need Screen Recording.
- Profiles, localization, and a Dock icon.
- Managing always-hidden apps inside Stow. That's handed to System Settings, because doing it in exam mode would keep the side effects on permanently.

## 3. Hard constraints

1. **macOS 27 only**, with `LSMinimumSystemVersion` 27.0.
2. **The only permission is Accessibility**, used to build the app list. Stow must never request or need **Screen Recording** or **Input Monitoring**.
3. **It runs from `/Applications/Stow.app`, unsandboxed.** Exam mode only recognizes the installed copy.
4. **It's signed with the local Apple Development identity**, auto-detected from the keychain, so the Accessibility grant survives rebuilds. Never ad-hoc.
5. **It fails safe.** No error path may leave icons hidden.
6. **No third-party packages.**
7. **Bundle ID** `studio.longbrook.stow`, display name **Stow**.

## 4. Behavior

### 4.1 States

| State | Exam mode | Meaning |
|---|---|---|
| **Hidden** | Assertion active with the allow-list (4.2) | The chosen apps' icons are gone |
| **Shown** | No assertion | Everything visible |
| **Unavailable** | No assertion | Exam mode can't be used (missing framework, refused call, or not in `/Applications`). Behaves like Shown |

**Transitions**
- *Click, shortcut, or menu item*: Hidden ↔ Shown. From Unavailable, a toggle retries activation once, and stays Unavailable with the latest reason if it fails again.
- *Auto re-hide timer*: Shown → Hidden (4.5).
- *Hide list becomes empty*: → Shown. Exam mode is never active with nothing to hide.
- *Hide list changes while Hidden*: re-activate with the new allow-list (4.4 ordering).
- *Activation error while entering Hidden*: → Unavailable, with the reason kept for the menu. (A failed *swap* while already Hidden is different: it keeps the old assertion and stays Hidden, see 4.4.)

### 4.2 The allow-list

```
allowedBundleIDs = unique(
    bundle IDs of running apps whose activation policy is .regular or .accessory
    ∪ { Stow's own bundle ID }
) − hiddenBundleIDs        (Stow's own ID is never removed)

allowedSystemItems = 0..<64   (keeps macOS's own items; same as upstream)
```

Both are passed as `NSArray`. Apps without a bundle ID can't be listed, so they hide whenever Stow is Hidden (see 4.7).

### 4.3 Launch, quit, crash

- **Launch** (including at login): if the hide list is non-empty and the environment checks pass (4.6), go to Hidden. Otherwise stay Shown.
- **Quit** (menu, ⌘Q, logout, shutdown): invalidate the assertion before exiting.
- **Crash or force-quit:** it's not yet known whether macOS releases the assertion when its process dies. That's on-device check 3 (§7.2) and a release gate. If the assertion survives, add a recovery path before v1 ships.

### 4.4 New apps while Hidden

On `NSWorkspace.didLaunchApplicationNotification`, debounced 0.5s, recompute the allow-list and swap assertions. **Activate the new assertion first, and invalidate the old one only after the new one succeeds**, so the bar never flashes fully visible. If the new activation fails, keep the old assertion and log it: a launched app might stay hidden, but nothing is stranded. App terminations need no update.

### 4.5 Auto re-hide

- **Delay:** Never, 5, 10 (default), 30 or 60 seconds.
- **Starting the timer:** any user action that moves to Shown starts it. Any manual hide cancels it.
- **When the delay elapses, Stow is "busy" if either is true:**
  - the pointer is inside any screen's menu bar strip, read via `NSEvent.mouseLocation`. The strip is the top `screen.frame.maxY − screen.visibleFrame.maxY` points, or 24pt if that's 0.
  - a pop-up menu is open: an on-screen window at `kCGPopUpMenuWindowLevel` in `CGWindowListCopyWindowInfo(.optionOnScreenOnly)`. This reads layer and bounds only, which need no Screen Recording.
- **If busy,** re-check every 1s, and hide the first time it isn't busy.

### 4.6 Environment checks

At launch, and before every activation:

1. `Bundle.main.bundleURL` is `/Applications/Stow.app`. Otherwise → Unavailable: "Move Stow to Applications to hide icons".
2. The exam-mode bridge reports it's available (§6.4). Otherwise → Unavailable: "Hiding isn't available on this version of macOS".

Accessibility is **not** required to hide. Its absence only affects the Settings list.

### 4.7 Known limits

Settings discloses these.

- Per app: all of an app's menu bar icons hide together.
- While Hidden, clicking the clock won't open Notification Center, and Focus and Now Playing may be hidden too.
- Mic/camera in-use indicator: reportedly hidden while Hidden. On-device check 4 decides the final wording. If it is hidden, the footnote says so plainly.
- Icons from tools without a bundle ID hide whenever Stow hides (for example, the ClickShare helper).

## 5. Interface

### 5.1 Menu bar icon: the drawer

Drawn in code as a vector `NSImage`. Geometry comes from the approved mockup, in points.

- **Closed (Hidden):** 16×14 template image, so the system tints it like other icons.
  - Cabinet: rounded rect (1.5, 1.7, 13 × 10.6), r 2.4, stroke 1.4.
  - Divider: line y = 7 from x 1.5 to 14.5, stroke 1.4.
  - Handles: (6.6, 4.4)–(9.4, 4.4) and (6.6, 9.6)–(9.4, 9.6), stroke 1.5, round caps.
- **Open (Shown):** 18×14, non-template, in amber.
  - Cabinet: rounded rect (1.5, 1.7, 11 × 10.6), r 2.4, stroke 1.4.
  - Drawer: filled rounded rect (5.5, 6.3, 11 × 6), r 1.6.
  - Handle: (9.6, 9.3)–(12.4, 9.3), stroke 1.4, round caps, drawn in the contrasting color.
- **Unavailable:** the closed drawer at 40% opacity.
- **Amber by menu bar appearance**, read from the status button's `effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])`:
  - dark bar: `#FFB340`, handle `#17130E` (9.35:1 against #1E1E1E);
  - light bar: `#A35400`, handle `#FFFFFF` (4.52:1 against #E6E9F0).
- **Accessibility label:** "Stow, N apps hidden" / "Stow, icons showing" / "Stow, hiding unavailable".
- **Clicks:** a left click toggles. A right click or Control-click opens the menu. Decide by event type or `NSEvent.modifierFlags`, never `NSApp.currentEvent.modifierFlags` (see findings, "Other traps").

### 5.2 Right-click menu

1. *Show Hidden Icons* (when Hidden), or *Hide Icons* (when Shown). It shows the current shortcut as a hint and is disabled while Unavailable.
2. A disabled status line, one of:
   - "Hiding N apps"
   - "Pick apps to hide in Settings"
   - "Hiding unavailable: ‹reason›"
   - "Move Stow to Applications to hide icons"
3. ——
4. *Settings…* ⌘,
5. *Quit Stow* ⌘Q

### 5.3 Settings window

A SwiftUI `Form` with `.formStyle(.grouped)`, about 440pt wide, following the system accent color and appearance. Window title: "Settings".

1. **Apps to hide**
   - One row per app: icon (22pt), name, switch. Alphabetical.
   - The list is the union of apps found with menu bar icons (§6.5) and apps in the hide list. Hidden apps that aren't running show "Not running" under their name.
   - Caption: "All of an app's menu bar icons hide together."
   - Empty state: "No apps with menu bar icons are running."
2. **Behavior**
   - *Hide again after*: a pop-up menu (Never / 5 seconds / 10 seconds / 30 seconds / 1 minute).
   - *Keyboard shortcut*: the recorder (§6.6).
   - *Open at login*: a switch bound to the live `SMAppService` state. If approval is needed, it shows "Approve Stow in System Settings › General › Login Items" with an *Open* button.
3. **Always hidden**
   - Text: "To keep an app out of the menu bar for good, turn it off in System Settings."
   - Button: *Open Menu Bar Settings…* (deep link, see open question 5).
4. **About hiding** (footnote): "Stow hides apps using macOS's exam mode. While icons are hidden, clicking the clock won't open Notification Center, and Focus and Now Playing may be hidden too." It gains the mic/camera clause if check 4 confirms it.

### 5.4 Banners

These appear at the top of the window, only when they apply.

- "Allow Accessibility so Stow can list your menu bar apps."
  - The *Open Privacy & Security* button calls `AXIsProcessTrustedWithOptions(prompt: true)` once and opens the Accessibility privacy pane.
  - While the banner shows, Stow polls trust every 1s and fills the list as soon as access is granted, with no relaunch.
- "Stow must be in the Applications folder to hide icons."

### 5.5 First run

When no preferences exist yet, Stow:
1. registers the login item (default on),
2. opens Settings, showing the Accessibility banner if trust is missing,
3. stays Shown until at least one app is chosen.

## 6. Architecture

### 6.1 Package layout

```
stow/
  Package.swift              tools 6.x; platform macOS 27
  Sources/
    ExamModeBridge/          Objective-C; public header in include/
    StowKit/                 Swift library: all logic and UI (testable, previewable)
      Hiding/                HideController, MenuBarRestriction (+ live implementation)
      MenuBar/               StatusItemController, DrawerGlyph
      Inventory/             MenuBarAppInventory (Accessibility)
      Settings/              Preferences, SettingsView, SettingsWindowController
      System/                GlobalShortcut, ShortcutRecorder, LoginItem, Environment
    Stow/                    executable: main.swift wires StowKit together
  Tests/StowKitTests/        Swift Testing
  Resources/                 Info.plist template, AppIcon.icns
  scripts/install.sh         build → bundle → sign → install → relaunch → verify
  scripts/make-icon.swift    renders the placeholder AppIcon.icns from DrawerGlyph geometry
  docs/
```

### 6.2 Components

Each one does one job, sits behind a small interface, and can be tested without the others.

| Component | Does | Interface (sketch) | Depends on |
|---|---|---|---|
| `MenuBarRestriction` | Turns the allow-list on and off | `activate(allowing: [String], systemItems: [Int]) async throws -> RestrictionToken`; `token.invalidate()`; `isAvailable` | ExamModeBridge (live), nothing (fake) |
| `HideController` | The state machine (§4), allow-list, app-launch refresh, auto re-hide | `state`, `toggle()`, `hide()`, `show()`, `prefsChanged()` | MenuBarRestriction, Preferences, Environment, a clock, a "busy" probe, a running-apps source |
| `StatusItemController` | Drawer icon, clicks, menu | observes `HideController.state`; calls `toggle()` | HideController, DrawerGlyph |
| `DrawerGlyph` | Draws the icon states and picks the amber shade | `image(for: state, appearance:) -> NSImage` | AppKit only |
| `MenuBarAppInventory` | Which running apps have menu bar icons | `isTrusted`, `requestTrust()`, `apps() -> [MenuBarApp]` | ApplicationServices (AX), NSWorkspace |
| `Preferences` | Saved settings | typed properties (§6.3), change notifications | UserDefaults |
| `SettingsView` / `SettingsWindowController` | The window (§5.3–5.5) | — | Preferences, Inventory, LoginItem, GlobalShortcut |
| `GlobalShortcut` | Registers the hot key | `register(keyCode:modifiers:) throws`, `onPress` | Carbon `RegisterEventHotKey` |
| `ShortcutRecorder` | Records a new shortcut | a SwiftUI view, bound to Preferences | AppKit key events (local only) |
| `LoginItem` | Open at login | `status`, `setEnabled(_:)`, `openSystemSettings()` | ServiceManagement `SMAppService.mainApp` |
| `Environment` | `/Applications` check | `isInstalledInApplications` | Bundle |

All UI and state types are `@MainActor`, built in the Swift 6 language mode with strict concurrency.

### 6.3 Saved preferences

These live in the `studio.longbrook.stow` user defaults.

| Key | Type | Default |
|---|---|---|
| `hiddenBundleIDs` | `[String]` | `[]` |
| `rehideDelaySeconds` | `Int` ∈ {0, 5, 10, 30, 60}; 0 = Never | `10` |
| `shortcutKeyCode` | `Int` (Carbon virtual key code); −1 = no shortcut | `4` (H) |
| `shortcutModifiers` | `Int` (Carbon modifier mask) | `controlKey \| optionKey` |

The login-item state is deliberately **not** stored. It's read live from `SMAppService`, so there's one source of truth.

### 6.4 Exam-mode bridge contract (Objective-C)

```objc
BOOL SXExamModeIsAvailable(void);
void SXExamModeActivate(NSArray<NSNumber *> *systemItems,
                        NSArray<NSString *> *bundleIDs,
                        void (^completion)(id _Nullable assertion, NSError * _Nullable error));
void SXExamModeInvalidate(id assertion);
```

- **`IsAvailable`** = `dlopen` succeeds, both classes exist, and they respond to `initWithAllowedSystemItems:allowedBundleIdentifiers:`, `activateWithConfiguration:completionHandler:` and `invalidate`.
- **Exceptions:** every call is wrapped in `@try/@catch`, and an exception becomes an `NSError`.
- **Threading:** completion runs on the main queue.
- **Nothing links the private framework at build time.** If macOS removes it, Stow launches and reports Unavailable.

### 6.5 Accessibility inventory

- Candidate apps are those running with activation policy `.regular` or `.accessory` and a bundle ID.
- For each: `AXUIElementCreateApplication(pid)`, then `AXUIElementSetMessagingTimeout(…, 0.25)`, then read `AXExtrasMenuBar`. An app has menu bar icons if that attribute exists and has at least one child.
- **Results:** a list of `MenuBarApp` (bundle ID, name, icon from `NSRunningApplication`). Hidden apps that aren't running get their name and icon via `NSWorkspace.urlForApplication(withBundleIdentifier:)`.
- **Refreshes** when Settings opens or becomes key, on app launch or quit while Settings is visible, and when trust becomes true.

### 6.6 Keyboard shortcut

- **Registration:** Carbon `RegisterEventHotKey` plus a `kEventHotKeyPressed` handler on the application event target. This needs no permission.
- **Conflicts:** `eventHotKeyExistsErr` shows "That shortcut is used by another app" under the recorder, and the previous shortcut stays registered.
- **Recording:** click the field and press keys. At least one of ⌃⌥⌘ is required (⇧ alone isn't enough). Esc cancels; Delete clears, which means no shortcut.
- **Display:** modifier symbols plus the key name. Character keys use `UCKeyTranslate` for the current layout. Special keys (F1–F20, arrows, Space, Return, Tab, Delete) use a table.

### 6.7 Build and install (`scripts/install.sh`)

1. Run `swift build -c release`.
2. Assemble `build/Stow.app`: the binary, the `Info.plist` (from the template, with version 0.1.0 and the git commit count as the build number) and `AppIcon.icns`.
3. Sign with the first "Apple Development:" identity from `security find-identity -v -p codesigning`. Stop with a clear message if none is found.
4. Quit any running Stow and wait for it to exit, so its assertion is released first.
5. Run `ditto build/Stow.app /Applications/Stow.app` and `open` it.
6. Verify, failing loudly if any check doesn't hold:
   - `codesign --verify --strict` passes;
   - the signing authority printed is the Apple Development identity;
   - the running process's path is `/Applications/Stow.app`.

**Info.plist:** `CFBundleIdentifier` studio.longbrook.stow, `CFBundleName`/`CFBundleDisplayName` Stow, `CFBundleExecutable` Stow, `LSUIElement` true, `LSMinimumSystemVersion` 27.0, `LSApplicationCategoryType` public.app-category.utilities, `CFBundleIconFile` AppIcon.

## 7. Testing and verification

### 7.1 Unit tests (`swift test`)

These use a fake `MenuBarRestriction` that records calls in order, plus an injected clock, busy probe and running-apps source.

- **Allow-list:** running apps − hide list + self. Apps without a bundle ID are skipped and the result is deduplicated. Only `.regular`/`.accessory` apps count. Stow is never removed.
- **States:** toggling works. An empty hide list never activates exam mode. Activation failure → Unavailable, with no assertion held. A toggle from Unavailable retries. Quit invalidates.
- **App launch while Hidden:** new activation, then the old one is invalidated (order asserted). A failed swap keeps the old assertion.
- **Auto re-hide:** fires at the delay, waits while busy (re-checked every 1s), Never disables it, and a manual hide cancels it.
- **Preferences:** defaults (10s, ⌃⌥H, empty list), round-trip persistence, and invalid delays clamped to the nearest allowed value.
- **Shortcut display:** ⌃⌥H, F-keys and arrows render correctly.
- **Contrast check:** both amber shades are ≥ 3:1 against the reference bars (#1E1E1E dark, #E6E9F0 light), and handle-on-drawer is ≥ 3:1. The test fails on a regression.

### 7.2 On-device checks (after `scripts/install.sh`)

Each check is backed by `screencapture -R` images of both menu bars, saved under `build/verification/`.

1. Hide and Show work on both displays. Chosen apps vanish, others stay, and Stow's icon stays.
2. An app launched while Hidden stays visible.
3. **Crash test (release gate):** `kill -9` Stow while Hidden and record whether the icons return.
4. **Mic/camera indicator** while Hidden (camera via Hand Mirror or FaceTime). Also record Focus, Now Playing and the clock click. Then set the footnote wording to match.
5. Sleep and wake, unplugging and replugging the Studio Display, and logout and login all keep the right state.
6. **Permissions from scratch:** run `tccutil reset All studio.longbrook.stow`, then use every feature. Only Accessibility is requested, and Stow never appears under Screen Recording or Input Monitoring. The grant survives two install cycles.
7. A copy run from outside `/Applications` shows the warning and doesn't hide.
8. The amber shade is right on a light and a dark menu bar, measured by sampling screenshot pixels.

### 7.3 Done means

`swift test` passes and on-device checks 1–8 pass on Nate's Mac with both displays connected. Results are recorded in `docs/verification.md`.

## 8. Risks

- **Apple closes or changes `MenuBarClientCore`** in a 27.x update. Stow goes Unavailable, and the fallback is the System Settings switches, by hand.
- **Exam mode's side effects** are inherent. They're disclosed, not fixed.
- **Assertion survives a crash** (unknown). Gated by check 3.

## 9. Open questions (verify during implementation, not decisions)

1. Does a force-quit release the assertion? (check 3)
2. Does the mic/camera indicator hide while Hidden? Does a wider `allowedSystemItems` range change that? (check 4)
3. Do hidden apps still report `AXExtrasMenuBar` children while Hidden? (Covered either way, because the list unions in the hide list.)
4. Does the status button's `effectiveAppearance` follow macOS 27's transparent menu bar (light vs dark)? Fallback: `NSApp.effectiveAppearance`.
5. Which URL opens System Settings › Menu Bar on 27? Fallback: open System Settings.
6. Are status item menus on 27 visible at `kCGPopUpMenuWindowLevel` in the window list? Fallback: the pointer-only busy rule. The same fallback applies if check 6 shows the window-list call causing any Screen Recording request: constraint 2 wins.
7. Does swapping assertions (4.4) flicker? (check 2)

## 10. Decisions log (2026-10-12)

| Decision | Why |
|---|---|
| Build Stow rather than install upstream v1.11.1 | Nate wants a custom design: a list-based picker and a personal look. Hiding behavior is identical either way |
| Exam mode as the engine | The only working live mechanism on 27. The divider trick and file-edited switches were tested and failed (see findings) |
| Fresh code, not a fork | The list-first design doesn't fit upstream's ⌘-drag sections, storyboards or two-engine structure |
| Pick apps from a list | Matches exam mode's per-app model, with no ⌘-dragging |
| Always-hidden goes to System Settings | Keeping it in exam mode would keep the side effects on permanently |
| C's drawer icon + A's settings window; amber only in the icon | Chosen from the mockups. Amber stays a status signal, and controls follow the system accent |
| Deeper amber on light menu bars | #FFB340 measures 1.47:1 on a light bar; #A35400 measures 4.52:1 |
| Accessibility for the list; no Screen Recording | An accurate list for one familiar permission. Nothing in Stow needs screen images |
| Swift package + install script, no Xcode project | Plain-text sources, no generated project files, a one-command dev loop. Must run from /Applications anyway |
| No third-party packages | Nothing to break when a package lags a macOS beta |
| Name: Stow, `studio.longbrook.stow` | Nate's pick. Matches Nate's other bundle IDs (`studio.longbrook.*`) |

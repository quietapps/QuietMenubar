<div align="center">

<img src="QuietMenubar/Resources/AppIcon.icns" alt="Quiet Menubar" width="128" height="128" />

# Quiet Menubar

**Your menu bar. Your rules. Only what you need.**

A native macOS menu bar manager that hides the icons you don't need until you ask for them — fast, private, and dependency-free. Part of the [Quiet Apps](https://github.com/quietapps) family.

[![macOS](https://img.shields.io/badge/macOS-12.0+-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![AppKit](https://img.shields.io/badge/AppKit-Swift-2396F3?logo=swift&logoColor=white)](https://developer.apple.com/documentation/appkit/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/quietapps/QuietMenubar?display_name=tag)](https://github.com/quietapps/QuietMenubar/releases)
[![Downloads](https://img.shields.io/github/downloads/quietapps/QuietMenubar/total.svg)](https://github.com/quietapps/QuietMenubar/releases)
[![Stars](https://img.shields.io/github/stars/quietapps/QuietMenubar?style=social)](https://github.com/quietapps/QuietMenubar/stargazers)

[Install](#install) · [Features](#features) · [Usage](#usage) · [Build from source](#build-from-source) · [FAQ](#faq)

</div>

---

## Why

You have twelve menu bar icons. You need three. The rest are noise — cluttering your screen, fighting for space near the notch, making the icons you actually use harder to find.

Quiet Menubar puts a `<` arrow and a `|` separator in your menu bar. Drag anything you don't need past the arrow, click to collapse, done. Your cleaned-up bar is one click away from the rest. No subscription. No cloud. No analytics.

Inspired by [Hidden Bar](https://github.com/dwarvesf/hidden). Rebuilt from scratch with the fixes users actually asked for — part of the free, open-source [Quiet Apps](https://github.com/quietapps) family.

## Features

**Current release:** version **1.0.0**, build **1** — see [CHANGELOG](CHANGELOG.md) for per-build notes

### Hide & reveal

- **Two-section menu bar** — drag icons left of the `<` arrow to hide them; icons right stay always visible
- **One-click toggle** — click the `<` arrow to show or hide your hidden section instantly
- **Global hotkey** — remappable keyboard shortcut toggles the hidden section system-wide (requires Accessibility)
- **Auto-hide** — optionally collapse the hidden section after a configurable delay (defaults to *Never* so you always choose)

### New icon behavior

- **New icons stay visible by default** — when you install a new app, its menu bar icon appears in the always-visible section. The original Hidden Bar would silently swallow new icons — the #1 complaint in its App Store reviews. You can opt back in under Preferences → General
- **30-second grace window on launch** — newly detected icons during startup land in the visible section automatically

### Customization

- **Arrow color** — choose any color, including a low-alpha "blend with menu bar" option that makes the separator nearly invisible
- **Auto-hide delay** — Never, 3 s, 5 s, 10 s, 30 s
- **Launch at login** — via `SMAppService` (macOS 13+) or manual on macOS 12

### Native macOS feel

- Menu bar agent — no Dock icon, no Task Switcher entry
- 100% Swift + AppKit — no SwiftUI for status-item logic
- No external dependencies — Apple frameworks only
- Notch-aware — clamps the expander width so icons never get stranded under the MacBook notch
- Multi-display aware

## Install

> **Note:** Quiet Menubar is not code-signed with an Apple Developer ID. macOS Gatekeeper will warn on first launch. The steps below work around it automatically.

### Homebrew (recommended)

```bash
brew tap quietapps/quietmenubar
brew install --cask quietmenubar
```

The cask strips the macOS quarantine attribute on install so Gatekeeper does not block launch. The tap is at [quietapps/homebrew-quietmenubar](https://github.com/quietapps/homebrew-quietmenubar).

### Direct download

1. Grab the latest `QuietMenubar-*.zip` from [Releases](https://github.com/quietapps/QuietMenubar/releases/latest)
2. Unzip → drag **Quiet Menubar.app** into `/Applications`
3. Strip the quarantine attribute (or right-click → Open once):

```bash
xattr -cr "/Applications/Quiet Menubar.app"
```

4. Launch Quiet Menubar — the `<` arrow and `|` bar appear in your menu bar
5. Grant **Accessibility** access when prompted to enable the global hotkey

### If the app doesn't open (Gatekeeper blocked it)

macOS silently blocks unsigned binaries on first launch. Fix it once with any of these:

**Option A — Right-click open (no Terminal needed)**
1. Open Finder → `/Applications`
2. Right-click **Quiet Menubar.app** → **Open**
3. Click **Open** in the warning dialog
4. macOS remembers your choice for every future launch

**Option B — Terminal**
```bash
xattr -cr "/Applications/Quiet Menubar.app"
```

**Option C — System Settings**
1. Try to launch the app — macOS shows a blocked notification
2. Open **System Settings → Privacy & Security**
3. Scroll to the message about Quiet Menubar
4. Click **Open Anyway**

## Updating

### Homebrew

```bash
brew update
brew upgrade --cask quietmenubar
```

### Direct download

Download the newer zip from [Releases](https://github.com/quietapps/QuietMenubar/releases), drag the new **Quiet Menubar.app** over the old one in `/Applications`, then run:

```bash
xattr -cr "/Applications/Quiet Menubar.app"
```

Your preferences are stored separately and are unaffected by app updates.

## Uninstalling

### Homebrew

```bash
# Remove the app and its preferences (via the cask's zap stanza)
brew uninstall --cask --zap quietmenubar

# Drop the tap
brew untap quietapps/quietmenubar

# Purge Homebrew's download cache
brew cleanup --prune=all -s
```

Optional manual cleanup if you skipped `--zap`:

```bash
defaults delete app.quiet.QuietMenubar 2>/dev/null
rm -rf ~/Library/Preferences/app.quiet.QuietMenubar.plist \
       ~/Library/Caches/app.quiet.QuietMenubar \
       ~/Library/Saved\ Application\ State/app.quiet.QuietMenubar.savedState
```

### Direct download

```bash
# Move the app to Trash
rm -rf "/Applications/Quiet Menubar.app"

# Remove preferences
defaults delete app.quiet.QuietMenubar 2>/dev/null
rm -rf ~/Library/Preferences/app.quiet.QuietMenubar.plist \
       ~/Library/Caches/app.quiet.QuietMenubar \
       ~/Library/Saved\ Application\ State/app.quiet.QuietMenubar.savedState
```

## Usage

| Action | How |
|---|---|
| Hide an icon | Hold ⌘ and drag it left of the `<` arrow |
| Show all hidden icons | Click the `<` arrow |
| Hide the hidden section again | Click the `<` arrow again |
| Toggle via keyboard | Global hotkey (configurable in Preferences) |
| Open Preferences | Click the `\|` bar → **Preferences…** |
| Right-click menu | Right-click the `<` arrow for quick actions |
| Quit | Click the `\|` bar → **Quit** |

### The two-separator layout

```
[hidden icons ...]  <  [always-visible icons ...]  |
                   ↑                               ↑
             toggle arrow                    preferences / quit
```

Icons dragged **left** of `<` are in the hidden section. Icons **right** of `<` are always visible. The `|` bar is fixed on the right edge of your always-visible section.

## Permissions

Quiet Menubar requests **Accessibility** access on first launch.

- **What it's used for:** registering a global keyboard shortcut so the show/hide toggle works system-wide
- **What it's NOT used for:** the app does not read your screen, your input, or any other app's data. Zero network calls

On first launch you'll see an onboarding window with a button to open **System Settings → Privacy & Security → Accessibility**. Flip the Quiet Menubar switch on. The app polls every two seconds and re-enables features automatically — no restart needed.

If you decline, everything works *except* the global hotkey.

## Build from source

### Requirements

- macOS 12.0 (Monterey) or later
- Xcode 15.0 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

No paid Apple Developer account required — the project uses automatic signing with any personal team.

### Steps

```bash
git clone https://github.com/quietapps/QuietMenubar.git
cd QuietMenubar
brew install xcodegen
xcodegen generate
open QuietMenubar.xcodeproj
```

Press **⌘R** in Xcode. The `<` arrow and `|` bar appear in your menu bar.

Or from the command line:

```bash
xcodebuild -project QuietMenubar.xcodeproj -scheme QuietMenubar -configuration Release build
```

### Bumping the version

`project.yml` is the single source of truth for the version. Edit `MARKETING_VERSION` there, then run `xcodegen generate`. Changes made in Xcode's Build Settings UI are lost on the next `xcodegen generate`.

### Project layout

```
QuietMenubar/
├── AppDelegate.swift                  # Lifecycle, hotkey registration, accessory policy
├── StatusBarController.swift          # Three NSStatusItems + expander-hiding mechanism
├── PreferencesWindowController.swift  # NSTabView preferences UI
├── HotKeyManager.swift                # Carbon RegisterEventHotKey + recorder helpers
├── LaunchAtLoginManager.swift         # SMAppService wrapper (macOS 13+) with fallback
├── AccessibilityManager.swift         # AXIsProcessTrusted polling + deep-link
├── OnboardingWindowController.swift   # First-launch explainer
├── AppSettings.swift                  # UserDefaults wrapper
├── NewItemWatcher.swift               # New-icons-stay-visible grace window
├── Info.plist                         # LSUIElement = YES, AX usage description
└── QuietMenubar.entitlements          # App Sandbox = NO
```

No external dependencies — Apple frameworks only (AppKit, Carbon, ServiceManagement).

## How it works

macOS provides **no API** to enumerate, hide, or reposition other apps' `NSStatusItem`s. The hiding mechanism is the same technique Hidden Bar pioneered: an invisible `NSStatusItem` of variable length is placed left of the `<` arrow. When you collapse, this expander grows wide enough to push everything left of it off the visible portion of the menu bar.

**Practical implications:**

- You must ⌘-drag your existing icons across the separators yourself — the app cannot move them for you
- The notch on MacBook Pro 14"/16" limits how far left the expander can push icons; Quiet Menubar clamps its width to `NSScreen.main.auxiliaryTopLeftArea.width` minus a safety margin to avoid stranding icons under the notch

## Configuration

All settings are in **Preferences** (click the `|` bar → **Preferences…**). Reset to defaults:

```bash
defaults delete app.quiet.QuietMenubar
```

## macOS Compatibility

| OS | Status | Notes |
|----|--------|-------|
| macOS 12 (Monterey) | Supported | Launch-at-login uses legacy `SMLoginItemSetEnabled`; prompts for manual enable |
| macOS 13 (Ventura) | Full support | `SMAppService.mainApp` for launch at login |
| macOS 14 (Sonoma) | Full support | `nudgeRedraw()` workaround for 1–2 pt residual gap on status item toggle |
| macOS 15 (Sequoia) | Full support | Same as Sonoma; notch width clamp more aggressively enforced |

## FAQ

**Does Quiet Menubar send any data anywhere?**
No. Zero network calls. No analytics, no telemetry.

**Why does it need Accessibility permission?**
To register a global keyboard shortcut via Carbon's `RegisterEventHotKey` API. macOS gates this behind Accessibility. The app does not read your screen, input, or any other app's data.

**Why can't it just hide icons automatically?**
macOS provides no API for one app to enumerate or move another app's `NSStatusItem`. You have to ⌘-drag icons past the separator yourself. This is the same constraint every menu bar manager faces.

**Why are my icons stuck under the notch?**
This happens when the expander grows too wide on a MacBook Pro with a notch. Quiet Menubar clamps the expander width to avoid it, but if you have an unusually large number of hidden icons the clamp may not be sufficient. Try moving a few icons back to the visible section.

**A new app's icon appeared in the hidden section.**
Go to **Preferences → General** and check **Keep new icons visible by default**. If the app launched before you could see it, drag the icon right of the `<` arrow to make it always visible.

**How do I remove the `|` bar from my menu bar?**
The `|` bar is Quiet Menubar's own control item — it's not removable while the app is running. Quit Quiet Menubar and it disappears.

**Where is Launch at Login on macOS 12?**
macOS 12 doesn't support `SMAppService`. Quiet Menubar shows an alert asking you to enable it manually in **System Settings → General → Login Items**. This is fixed on macOS 13+.

**How do I quit?**
Click the `|` bar → **Quit**.

## License

[MIT](LICENSE) © Quiet Apps

Inspired by [Hidden Bar](https://github.com/dwarvesf/hidden). Independent implementation, rewritten from scratch.

---

<div align="center">
If Quiet Menubar cleans up your menu bar, drop a ⭐ on the repo.
</div>

# Changelog

All notable changes to Quiet Menubar are documented here.

Format: version **X.Y.Z**, build **N** — newest first.

---

## 1.0.0 — build 1 (2026-06-17)

Initial public release.

### Added

- Two-separator menu bar layout — `<` arrow toggles hidden section, `|` bar opens Preferences / Quit
- ⌘-drag to move icons between hidden and always-visible sections
- Global hotkey to toggle the hidden section (configurable, requires Accessibility)
- Auto-hide delay — Never, 3 s, 5 s, 10 s, 30 s (defaults to Never)
- **New icons stay visible by default** — 30-second grace window on launch prevents newly installed app icons from disappearing into the hidden section
- Arrow color customization — any color, including a low-alpha "blend" option
- Launch at login — `SMAppService` on macOS 13+, manual fallback on macOS 12
- Onboarding window for Accessibility permission with polling-based auto-recovery
- Notch-aware expander width clamp for MacBook Pro 14"/16"
- macOS 12 (Monterey) through macOS 15 (Sequoia) support
- XcodeGen-based project — `.xcodeproj` not committed, generated from `project.yml`

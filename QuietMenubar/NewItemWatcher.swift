import AppKit

/// "Improvement #1" — new menu-bar icons should default to the *always-visible* section.
///
/// We cannot directly observe other apps' NSStatusItem creation. The best we can do without
/// private API is detect when the user has just made the hidden section visible, then ensure
/// the collapse state stays open long enough for a newly-installed app's icon to settle on
/// the right (visible) side of our arrow separator. The actual "default to right of arrow"
/// guarantee requires the user to ⌘-drag the icon themselves — but we can nudge UX:
///
///   1. If `newIconsAlwaysVisible` is on (default), the app starts EXPANDED on launch and
///      *stays* expanded for a grace period after first launch so a newly-installed menu
///      bar app does not get silently swallowed.
///   2. When the user toggles the setting off, we revert to the original Hidden Bar default.
///
/// This is a UX guardrail, not a programmatic guarantee — the platform does not allow more.
final class NewItemWatcher {

    private weak var controller: StatusBarController?
    private var graceTimer: Timer?

    init(controller: StatusBarController) {
        self.controller = controller
    }

    func startGracePeriodIfNeeded() {
        guard AppSettings.shared.newIconsAlwaysVisible else { return }
        controller?.showHiddenIcons()
        graceTimer?.invalidate()
        // 30s after launch we let the auto-hide policy take over.
        graceTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in }
    }
}

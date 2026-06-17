import AppKit
import ApplicationServices

/// Accessibility permission is required for the global hot-key recorder and for any
/// AX-based introspection of the menu bar. macOS will not let third-party apps mutate
/// other apps' menu bar items without it — we still cannot move them programmatically,
/// but the AX API is the gate that even *reading* the menu bar layout passes through.
final class AccessibilityManager {

    static let shared = AccessibilityManager()

    /// Posted whenever the trust state flips. Observers should refresh UI/hot-key bindings.
    static let trustChangedNotification = Notification.Name("QuietMenubar.accessibilityTrustChanged")

    private var lastKnownTrusted: Bool = false
    private var pollTimer: Timer?

    private init() {
        lastKnownTrusted = isTrusted()
    }

    /// Non-prompting check. Safe to call repeatedly (does not pop the system sheet).
    func isTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompts the user with Apple's system sheet asking to enable Accessibility for us.
    /// Only call this once during onboarding — repeated calls can be perceived as nagware.
    @discardableResult
    func promptForTrust() -> Bool {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        return AXIsProcessTrustedWithOptions(opts)
    }

    func openAccessibilityPane() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Start a polling timer + app-activation hook to detect when the user grants/revokes
    /// permission so we can transition out of the onboarding screen automatically.
    func startMonitoring() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidBecomeActive),
                                               name: NSApplication.didBecomeActiveNotification,
                                               object: nil)
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkTrustChange()
        }
    }

    @objc private func appDidBecomeActive() {
        checkTrustChange()
    }

    private func checkTrustChange() {
        let now = isTrusted()
        if now != lastKnownTrusted {
            lastKnownTrusted = now
            NotificationCenter.default.post(name: AccessibilityManager.trustChangedNotification, object: nil)
        }
    }
}

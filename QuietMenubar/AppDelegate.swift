import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var newItemWatcher: NewItemWatcher!
    private var onboarding: OnboardingWindowController?
    private var prefsWindow: PreferencesWindowController?

    static var shared: AppDelegate? { NSApp.delegate as? AppDelegate }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders: even with LSUIElement=YES in Info.plist, set the activation
        // policy explicitly so a stray window doesn't accidentally promote us to a dock app.
        NSApp.setActivationPolicy(.accessory)

        statusBarController = StatusBarController()
        newItemWatcher = NewItemWatcher(controller: statusBarController)

        registerHotKey()

        if !AppSettings.shared.hasOnboarded || !AccessibilityManager.shared.isTrusted() {
            showOnboarding()
        }

        AccessibilityManager.shared.startMonitoring()
        newItemWatcher.startGracePeriodIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    // Note: previously we re-asserted .accessory on every applicationDidBecomeActive to
    // prevent stray Dock-icon promotion. That now fights PreferencesWindowController,
    // which deliberately switches to .regular while the window is open. The controller
    // restores .accessory in windowWillClose, so the unconditional assertion is gone.

    /// Fired when the user "reopens" the app from Finder / Spotlight / Dock while it's
    /// already running. We use this as the lockout escape hatch — if the user has
    /// accidentally dragged our status items off-screen, they can re-launch the app and
    /// the Preferences window will pop up, exposing the "Reset Layout" button.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openPreferences()
        return true
    }

    func openPreferences() {
        if prefsWindow == nil { prefsWindow = PreferencesWindowController() }
        prefsWindow?.showWindow(nil)
    }

    func resetStatusBarLayout() {
        statusBarController?.resetLayoutPublic()
    }

    private func registerHotKey() {
        let kc = AppSettings.shared.hotKeyKeyCode
        let mods = AppSettings.shared.hotKeyModifiers
        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.statusBarController.toggleCollapse()
        }
        if kc != 0 {
            HotKeyManager.shared.register(keyCode: kc, modifiers: mods)
        }
    }

    private func showOnboarding() {
        let o = OnboardingWindowController()
        onboarding = o
        o.onDismiss = { [weak self] in self?.onboarding = nil }
        o.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

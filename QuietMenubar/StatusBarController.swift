import AppKit

/// Manages the three (optionally four) NSStatusItems that compose Quiet Menubar's separators.
///
/// LAYOUT (visually, left-to-right in the menu bar):
///     [ alwaysHiddenBar "||" ]?  …user icons…  [ collapseArrow "<" ]  …user icons…  [ visibleBar "|" ]
///
/// macOS lays out NSStatusItems right-to-left from the system items, so the items closest to
/// the trailing edge get created last — see `setupStatusItems()`.
///
/// HIDING MECHANISM
/// macOS provides NO API to hide other apps' status items. Hidden Bar's "trick" is to make a
/// hidden *expander* NSStatusItem grow wide enough that the user-icons positioned to its left
/// get pushed off the visible portion of the menu bar (clipped at `auxiliaryTopLeftArea` on
/// notched screens, or at the screen edge on non-notched screens). When the user wants the
/// icons back, we shrink the expander to zero.
///
/// FRAGILITY NOTE — read before changing
/// - Big Sur changed the backing window of status items; we rely on `button?.window?.frame`
///   for any positional math, which is still functional on Sonoma/Sequoia but undocumented.
/// - Sonoma sometimes leaves residual gaps when toggling `isVisible`; we double-toggle length
///   via `nudgeRedraw()` to force a re-layout.
/// - The expander width is clamped to the screen's left auxiliary area on notched Macs to
///   avoid items getting truncated by AppKit and remaining partially visible under the notch.
final class StatusBarController: NSObject {

    // The arrow toggle — RIGHTMOST of our items so growing the bar to its left never
    // pushes the arrow off-screen.
    private var arrowItem: NSStatusItem!
    // The `│` boundary bar — LEFT of the arrow. Grows leftward on collapse to shove the
    // hidden-zone icons (placed left of this bar) off the visible menu bar.
    private var visibleBarItem: NSStatusItem!
    // Optional `‖` bar for the always-hidden section — LEFT of the `│` bar. Grows on
    // always-hidden collapse to shove the always-hidden zone (left of this bar) off.
    private var alwaysHiddenBarItem: NSStatusItem?


    private var isCollapsed: Bool = false
    private var isAlwaysHiddenCollapsed: Bool = AppSettings.shared.alwaysHiddenCollapsed
    private var hasAppliedInitialState: Bool = false
    private var autoHideTimer: Timer?

    private var prefsWindowController: PreferencesWindowController?
    private var contextMenu: NSMenu!

    override init() {
        super.init()
        setupStatusItems()
        rebuildContextMenu()
        applyArrowColor()
        applyAlwaysHiddenSection()
        observeSettings()
        // Start collapsed if the user previously left us collapsed? No — always start expanded
        // on launch so newly-added icons are visible. Restoring collapse state silently has
        // the same UX problem Hidden Bar got dinged for (icons "disappearing" on launch).
        setCollapsed(false, animated: false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        autoHideTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupStatusItems() {
        let bar = NSStatusBar.system

        // Created left-to-right in source = appears right-to-left in menu bar.
        // We want: arrow | visibleBar  (with arrow LEFT of visibleBar)
        // So create visibleBar first (rightmost), then arrow.
        // NSStatusItem.variableLength sizes to fit the image/title automatically — that is
        // what makes the icon actually visible on first paint. Fixed lengths smaller than
        // the rendered content get clipped to invisible on some macOS versions.
        // Match Hidden Bar (Dwarves Foundation) layout:
        //   [bar │]  [arrow ‹]  [system]
        // arrowItem is created FIRST so it sits closer to system items. visibleBarItem
        // is created SECOND so it ends up LEFT of the arrow — and IS the expander.
        // Growing visibleBarItem.length leftward pushes hidden-zone icons (left of
        // bar) off the visible menu bar. Arrow (right of bar) is never moved.
        arrowItem = bar.statusItem(withLength: NSStatusItem.variableLength)
        configureArrow(arrowItem)
        arrowItem.autosaveName = "quietmenubar_arrow"

        visibleBarItem = bar.statusItem(withLength: collapsedNarrowLength)
        configureVisibleBar(visibleBarItem)
        visibleBarItem.autosaveName = "quietmenubar_separator"

        // If the user previously ⌘-dragged either item off the menu bar, macOS persists
        // that hidden state via autosaveName. Re-assert visibility on every launch so
        // the only UI we have is always reachable.
        arrowItem.isVisible = true
        visibleBarItem.isVisible = true

        let vbFrame = visibleBarItem.button?.window?.frame.size ?? .zero
        let arFrame = arrowItem.button?.window?.frame.size ?? .zero
        NSLog("QuietMenubar: visibleBar size=\(vbFrame) arrow size=\(arFrame)")
    }

    // Hidden Bar's defaults: 20pt narrow, ~min(screenWidth*2, 10000) wide.
    private var collapsedNarrowLength: CGFloat { 20 }
    private var collapsedWideLength: CGFloat {
        let widest = NSScreen.screens.map(\.frame.width).max() ?? 1728
        return max(500, min(widest * 2, 10_000))
    }

    private func configureVisibleBar(_ item: NSStatusItem) {
        guard let button = item.button else { return }
        button.title = ""
        button.image = StatusBarController.verticalBarImage()
        // Center the glyph inside its container so when the item is at its narrow
        // (expanded) state there is no extra padding either side. On collapse the
        // container grows leftward and AppKit re-centers the image — that creates the
        // leftward "hide" push without any visible gap on the right.
        button.alignment = .center
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(visibleBarClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Quiet Menubar — click for menu"
    }

    /// 1.5pt wide template line, ~16pt tall — matches the visual weight of SF Symbol
    /// status items and centers automatically inside the NSStatusBarButton.
    private static func verticalBarImage(thickness: CGFloat = 1.5, height: CGFloat = 16) -> NSImage {
        let size = NSSize(width: max(thickness, 2), height: height)
        let img = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(rect: NSRect(x: (rect.width - thickness) / 2,
                                                 y: 0,
                                                 width: thickness,
                                                 height: rect.height))
            NSColor.labelColor.setFill()
            path.fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    /// Heavier double-bar variant for the always-hidden separator.
    private static func doubleBarImage() -> NSImage {
        let thickness: CGFloat = 1.5
        let gap: CGFloat = 2.5
        let height: CGFloat = 16
        let size = NSSize(width: thickness * 2 + gap, height: height)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor.labelColor.setFill()
            NSBezierPath(rect: NSRect(x: 0, y: 0, width: thickness, height: rect.height)).fill()
            NSBezierPath(rect: NSRect(x: thickness + gap, y: 0, width: thickness, height: rect.height)).fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    private func configureArrow(_ item: NSStatusItem) {
        guard let button = item.button else { return }
        applyArrowAppearance(button: button)
        button.target = self
        button.action = #selector(arrowClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Click to show/hide menu bar icons"
    }

    /// Renders the arrow as an SF Symbol (preferred) or a unicode chevron fallback.
    /// SF Symbols give us a proper template image that adopts the menu bar's dark/light
    /// tinting automatically and is visibly larger than the `<`/`>` ASCII glyphs.
    private func applyArrowAppearance(button: NSStatusBarButton) {
        let isRTL = NSApp.userInterfaceLayoutDirection == .rightToLeft
        let leftFacing  = isCollapsed ? !isRTL : isRTL
        let symbolName  = leftFacing ? "chevron.left" : "chevron.right"

        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle hidden icons") {
            // Heavy weight + 16pt: visible against Tahoe's translucent menu bar where lighter
            // template glyphs disappear into the wallpaper.
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .heavy)
            let configured = img.withSymbolConfiguration(config)
            configured?.isTemplate = (AppSettings.shared.arrowColorOption == .systemLabel)
            button.image = configured
            button.title = ""
        } else {
            button.image = nil
            button.title = arrowGlyph()
            button.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        }
    }

    // MARK: - Public API

    func toggleCollapse() {
        setCollapsed(!isCollapsed, animated: true)
    }

    func showHiddenIcons() {
        setCollapsed(false, animated: true)
        scheduleAutoHideIfNeeded()
    }

    func hideHiddenIcons() {
        setCollapsed(true, animated: true)
    }

    // MARK: - Collapse logic

    private func setCollapsed(_ collapsed: Bool, animated: Bool) {
        // Avoid redundant work when state is unchanged (e.g. NewItemWatcher's grace-period
        // expand-on-launch fires after init() already expanded). First call always runs so
        // the initial length is actually applied.
        if hasAppliedInitialState && collapsed == isCollapsed {
            return
        }
        hasAppliedInitialState = true
        isCollapsed = collapsed

        // Both UI separators forced visible — earlier "hide arrow when collapsed" feature
        // could lock the user out completely. Removed in favor of an always-clickable UI.
        visibleBarItem.isVisible = true
        arrowItem.isVisible = true
        if let button = arrowItem.button {
            applyArrowAppearance(button: button)
            applyArrowColor()
        }

        if collapsed {
            // Hidden Bar's position-validity guard: if the user ⌘-dragged the arrow LEFT
            // of the bar, growing the bar would push the arrow off-screen. Refuse to
            // collapse in that state — they get the existing layout, no lockout. The
            // arrow's current X must be >= bar's current X (LTR).
            guard isArrowRightOfBar else {
                NSLog("QuietMenubar: refusing collapse — arrow is left of bar, would push arrow off-screen")
                isCollapsed = false
                return
            }
            visibleBarItem.button?.alignment = .right
            visibleBarItem.length = collapsedWideLength
        } else {
            visibleBarItem.button?.alignment = .center
            visibleBarItem.length = collapsedNarrowLength
            autoHideTimer?.invalidate()
            autoHideTimer = nil
        }
        NSLog("QuietMenubar: collapsed=\(collapsed) bar.length=\(visibleBarItem.length)")

        nudgeRedraw()

        if !collapsed { scheduleAutoHideIfNeeded() }
    }

    /// Returns a width large enough to push user icons placed left of the bar off the
    /// visible portion of the menu bar — clamped so the arrow's current on-screen
    /// position cannot be shoved past the left edge of the menu bar (or under the notch
    /// on notched MacBooks). The user can ⌘-drag the arrow anywhere; this clamp adapts
    /// to whatever position it ended up in, guaranteeing the arrow stays visible.
    /// Hidden Bar's position-validity check translated for this app: arrow must sit
    /// RIGHT of (or at the same X as) the bar in LTR, LEFT in RTL. Implemented by
    /// reading each item's button's window origin — same approach as Hidden Bar's
    /// `getOrigin` extension. If either window has no frame yet (early launch) we
    /// optimistically return true so the first auto-collapse can still run.
    private var isArrowRightOfBar: Bool {
        guard let arrowX = arrowItem.button?.window?.frame.origin.x,
              let barX = visibleBarItem.button?.window?.frame.origin.x else {
            return true
        }
        let isRTL = NSApp.userInterfaceLayoutDirection == .rightToLeft
        return isRTL ? arrowX <= barX : arrowX >= barX
    }


    /// Sonoma/Tahoe sometimes leave a stale 1–2 pt residual gap on length change. Forcing
    /// the expander length to flip via a zero-step nudge gets AppKit to re-flow the bar.
    /// Resolve a status item's button frame into global screen coordinates. Reading
    /// `button.window.frame` directly returns the same value for every item on Tahoe
    /// (apparently the container window, not per-item) so we have to convert through the
    /// button's own bounds.
    private func screenFrame(of item: NSStatusItem) -> NSRect {
        guard let button = item.button, let window = button.window else { return .zero }
        let boundsInWindow = button.convert(button.bounds, to: nil)
        let screen = window.convertToScreen(boundsInWindow)
        NSLog("QuietMenubar: frame breakdown — buttonBounds=\(button.bounds) buttonFrame=\(button.frame) inWindow=\(boundsInWindow) windowFrame=\(window.frame) screen=\(screen)")
        return screen
    }

    private func nudgeRedraw() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let current = self.visibleBarItem.length
            guard current >= 0 else { return }
            self.visibleBarItem.length = current + 0.0001
            DispatchQueue.main.async { [weak self] in
                self?.visibleBarItem.length = current
            }
        }
    }

    // MARK: - Auto-hide

    private func scheduleAutoHideIfNeeded() {
        autoHideTimer?.invalidate()
        let delay = AppSettings.shared.autoHideDelay
        guard delay != .never else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(delay.rawValue),
                                             repeats: false) { [weak self] _ in
            self?.hideHiddenIcons()
        }
    }

    // MARK: - Click handlers

    @objc private func visibleBarClicked(_ sender: Any?) {
        // Left- and right-click both open the menu — no branch on event required.
        NSLog("QuietMenubar: visibleBar clicked")
        showMenu(under: visibleBarItem)
    }

    @objc private func arrowClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        NSLog("QuietMenubar: arrow clicked right=\(isRightClick) collapsed=\(isCollapsed)")
        if isRightClick {
            showMenu(under: arrowItem)
            return
        }
        toggleCollapse()
    }

    @objc private func alwaysHiddenBarClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        NSLog("QuietMenubar: alwaysHiddenBar clicked right=\(isRightClick) collapsed=\(isAlwaysHiddenCollapsed)")
        if isRightClick {
            if let item = alwaysHiddenBarItem { showMenu(under: item) }
            return
        }
        isAlwaysHiddenCollapsed.toggle()
        AppSettings.shared.alwaysHiddenCollapsed = isAlwaysHiddenCollapsed
        applyAlwaysHiddenState(forceRedraw: true)
        rebuildContextMenu()
    }

    /// Drive the `||` bar's own `.length`. Same trick as the main visibleBar — grow
    /// leftward to shove the always-hidden zone off-screen, shrink to reveal it.
    private func applyAlwaysHiddenState(forceRedraw: Bool) {
        guard let bar = alwaysHiddenBarItem else { return }
        if isAlwaysHiddenCollapsed {
            bar.button?.alignment = .right
            bar.length = collapsedWideLength
        } else {
            bar.button?.alignment = .center
            bar.length = collapsedNarrowLength
        }
        NSLog("QuietMenubar: alwaysHidden collapsed=\(isAlwaysHiddenCollapsed) bar.length=\(bar.length)")
        if forceRedraw {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let bar = self.alwaysHiddenBarItem else { return }
                let cur = bar.length
                guard cur >= 0 else { return }
                bar.length = cur + 0.0001
                DispatchQueue.main.async { [weak self] in
                    self?.alwaysHiddenBarItem?.length = cur
                }
            }
        }
    }

    // MARK: - Menu

    private func rebuildContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Hidden Icons",
                                action: #selector(showFromMenu(_:)),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Hide Icons",
                                action: #selector(hideFromMenu(_:)),
                                keyEquivalent: ""))
        if AppSettings.shared.enableAlwaysHiddenSection {
            menu.addItem(.separator())
            let title = isAlwaysHiddenCollapsed
                ? "Reveal Always-Hidden Icons"
                : "Hide Always-Hidden Icons"
            menu.addItem(NSMenuItem(title: title,
                                    action: #selector(toggleAlwaysHiddenFromMenu(_:)),
                                    keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Reset Layout",
                                action: #selector(resetLayout(_:)),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences…",
                                action: #selector(openPreferences(_:)),
                                keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Quiet Menubar",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        contextMenu = menu
    }

    private func showMenu(under item: NSStatusItem) {
        item.menu = contextMenu
        item.button?.performClick(nil)
        // Detach so the next click triggers our action again, not the menu.
        DispatchQueue.main.async { item.menu = nil }
    }

    @objc private func showFromMenu(_ sender: Any?) { showHiddenIcons() }
    @objc private func hideFromMenu(_ sender: Any?) { hideHiddenIcons() }

    /// Remove and re-create our status items in the canonical order. Used when the user
    /// accidentally ⌘-drags items into the wrong positions — macOS persists the user's
    /// drag, so a hard re-create is the only way to get back to defaults without
    /// requiring the user to ⌘-drag manually.
    func resetLayoutPublic() { resetLayout(nil) }

    @objc private func resetLayout(_ sender: Any?) {
        NSLog("QuietMenubar: resetLayout invoked")
        // Removing a status item triggers `_clearAutosavedPreferredPosition`, which posts
        // a UserDefaults-change notification synchronously inside the dealloc. Our own
        // settingsChanged observer reads back arrowItem / visibleBarItem — re-entrant
        // during the swap-in below, that read trips Swift's exclusivity check and
        // crashes the process. Detach the observer for the duration of the reset.
        NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)

        if let item = alwaysHiddenBarItem {
            NSStatusBar.system.removeStatusItem(item)
            alwaysHiddenBarItem = nil
        }
        NSStatusBar.system.removeStatusItem(visibleBarItem)
        NSStatusBar.system.removeStatusItem(arrowItem)

        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
            where key.hasPrefix("NSStatusItem Preferred Position") {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()

        isCollapsed = false
        hasAppliedInitialState = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            self.setupStatusItems()
            self.applyArrowColor()
            self.applyAlwaysHiddenSection()
            self.setCollapsed(false, animated: false)
            // Re-attach the observer once items are stable.
            self.observeSettings()
            NSLog("QuietMenubar: resetLayout complete — visibleBar=\(self.visibleBarItem.isVisible) arrow=\(self.arrowItem.isVisible)")
        }
    }

    @objc private func toggleAlwaysHiddenFromMenu(_ sender: Any?) {
        isAlwaysHiddenCollapsed.toggle()
        AppSettings.shared.alwaysHiddenCollapsed = isAlwaysHiddenCollapsed
        applyAlwaysHiddenState(forceRedraw: true)
        rebuildContextMenu()
    }

    @objc private func openPreferences(_ sender: Any?) {
        if prefsWindowController == nil {
            prefsWindowController = PreferencesWindowController()
        }
        prefsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Settings observation

    private func observeSettings() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }

    @objc private func settingsChanged() {
        applyArrowColor()
        applyAlwaysHiddenSection()
        rebuildContextMenu()
        arrowItem.isVisible = true
        visibleBarItem.isVisible = true
    }

    // MARK: - Arrow appearance

    private func arrowGlyph() -> String {
        // RTL note: in RTL locales the visual direction flips automatically because the
        // status bar lays out in the user's writing direction; we still keep the semantic
        // "collapse points toward the hidden side" by flipping the glyph for RTL.
        let isRTL = NSApp.userInterfaceLayoutDirection == .rightToLeft
        if isCollapsed {
            return isRTL ? "<" : ">"
        } else {
            return isRTL ? ">" : "<"
        }
    }

    private func applyArrowColor() {
        guard let button = arrowItem?.button else { return }
        let option = AppSettings.shared.arrowColorOption

        // For "system" we use the SF Symbol's template behavior (auto-tints to menu bar
        // foreground). For any explicit color we have to render a tinted image manually
        // because NSStatusBarButton ignores .contentTintColor on template images on some
        // macOS versions.
        if option == .systemLabel {
            button.contentTintColor = nil
            if let baseImg = button.image { baseImg.isTemplate = true }
            return
        }

        let color = currentArrowColor()
        if let img = button.image {
            img.isTemplate = false
            button.contentTintColor = color
        } else {
            let attr: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 14, weight: .bold)
            ]
            button.attributedTitle = NSAttributedString(string: arrowGlyph(), attributes: attr)
        }
    }

    private func currentArrowColor() -> NSColor {
        switch AppSettings.shared.arrowColorOption {
        case .systemLabel: return .labelColor
        case .white: return .white
        case .black: return .black
        case .menubarBlend:
            // The menu bar background is dynamic (depends on wallpaper + dark mode).
            // Best blend we can do without screen-capture is a low-alpha label color.
            return NSColor.labelColor.withAlphaComponent(0.25)
        case .custom: return AppSettings.shared.customArrowColor
        }
    }

    // MARK: - Always-hidden section (optional)

    private func applyAlwaysHiddenSection() {
        let enabled = AppSettings.shared.enableAlwaysHiddenSection
        if enabled && alwaysHiddenBarItem == nil {
            // Bar item (the visible `||` separator).
            let bar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = bar.button {
                button.title = ""
                button.image = StatusBarController.doubleBarImage()
                button.alignment = .center
                button.imagePosition = .imageOnly
                button.target = self
                button.action = #selector(alwaysHiddenBarClicked(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.toolTip = "Always-hidden section — click to toggle"
            }
            alwaysHiddenBarItem = bar
            // Defer the first apply — at init time arrowItem's NSWindow hasn't laid out
            // yet, so computeExpanderWidth() would fall back to its 80pt minimum and the
            // always-hidden zone wouldn't actually get pushed off.
            DispatchQueue.main.async { [weak self] in
                self?.applyAlwaysHiddenState(forceRedraw: true)
            }
        } else if !enabled {
            if let item = alwaysHiddenBarItem {
                NSStatusBar.system.removeStatusItem(item)
                alwaysHiddenBarItem = nil
            }
        }
    }
}

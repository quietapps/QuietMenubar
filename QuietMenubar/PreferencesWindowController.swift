import AppKit
import Carbon.HIToolbox

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Quiet Menubar Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.delegate = self
        window.contentView = makeTabView()
    }

    override func showWindow(_ sender: Any?) {
        // Promote to a regular app while Preferences is open so the Dock icon appears.
        // We revert to .accessory in windowWillClose.
        NSApp.setActivationPolicy(.regular)
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
    }

    func windowWillClose(_ notification: Notification) {
        // Hide the Dock icon again on a short delay — closing inside the window's own
        // event handler and immediately calling setActivationPolicy can trigger an
        // AppKit assertion. Async to next runloop tick avoids it.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func makeTabView() -> NSView {
        let tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 520, height: 360))
        tabView.addTabViewItem(tab("General", view: GeneralPrefsView()))
        tabView.addTabViewItem(tab("Appearance", view: AppearancePrefsView()))
        tabView.addTabViewItem(tab("Shortcut", view: ShortcutPrefsView()))
        tabView.addTabViewItem(tab("Advanced", view: AdvancedPrefsView()))
        return tabView
    }

    private func tab(_ label: String, view: NSView) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: label)
        item.label = label
        item.view = view
        return item
    }
}

// MARK: - General

final class GeneralPrefsView: NSView {

    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at login",
                                                 target: nil, action: nil)
    private let newIconsCheckbox = NSButton(checkboxWithTitle:
        "New menu bar icons default to Always Visible",
        target: nil, action: nil)
    private let autoHidePopup = NSPopUpButton()

    init() {
        super.init(frame: .zero)
        setupViews()
        loadValues()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let title = NSTextField(labelWithString: "General")
        title.font = .boldSystemFont(ofSize: 16)

        autoHidePopup.target = self
        autoHidePopup.action = #selector(autoHideChanged(_:))
        for opt in AutoHideDelay.allCases {
            autoHidePopup.addItem(withTitle: opt.label)
            autoHidePopup.lastItem?.tag = opt.rawValue
        }

        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchChanged(_:))

        newIconsCheckbox.target = self
        newIconsCheckbox.action = #selector(newIconsChanged(_:))

        let hideLabel = NSTextField(labelWithString: "Auto-hide hidden icons:")
        let footnote = NSTextField(wrappingLabelWithString:
            "When enabled, brand-new menu bar icons added by other apps stay visible until you drag them into the hidden section. This avoids accidentally losing track of new apps' icons.")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            title,
            launchAtLoginCheckbox,
            stackedRow(hideLabel, autoHidePopup),
            newIconsCheckbox,
            footnote
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    private func stackedRow(_ a: NSView, _ b: NSView) -> NSStackView {
        let s = NSStackView(views: [a, b])
        s.orientation = .horizontal
        s.spacing = 8
        return s
    }

    private func loadValues() {
        launchAtLoginCheckbox.state = AppSettings.shared.launchAtLogin ? .on : .off
        newIconsCheckbox.state = AppSettings.shared.newIconsAlwaysVisible ? .on : .off
        autoHidePopup.selectItem(withTag: AppSettings.shared.autoHideDelay.rawValue)
    }

    @objc private func launchChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        let ok = LaunchAtLoginManager.setEnabled(enabled)
        AppSettings.shared.launchAtLogin = ok && enabled
        if !ok && enabled {
            sender.state = .off
            let alert = NSAlert()
            alert.messageText = "Could not enable launch at login"
            alert.informativeText = "Your macOS version may require additional setup. See the README."
            alert.runModal()
        }
    }

    @objc private func newIconsChanged(_ sender: NSButton) {
        AppSettings.shared.newIconsAlwaysVisible = (sender.state == .on)
    }

    @objc private func autoHideChanged(_ sender: NSPopUpButton) {
        if let tag = sender.selectedItem?.tag, let opt = AutoHideDelay(rawValue: tag) {
            AppSettings.shared.autoHideDelay = opt
        }
    }
}

// MARK: - Appearance

final class AppearancePrefsView: NSView {

    private let colorPopup = NSPopUpButton()
    private let customColorWell = NSColorWell(frame: NSRect(x: 0, y: 0, width: 44, height: 24))
    private let fullBarCheckbox = NSButton(checkboxWithTitle:
        "Full menu bar mode (expand across whole bar)", target: nil, action: nil)
    private let alwaysHiddenCheckbox = NSButton(checkboxWithTitle:
        "Enable second 'Always Hidden' section", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        setupViews()
        loadValues()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let title = NSTextField(labelWithString: "Appearance")
        title.font = .boldSystemFont(ofSize: 16)

        for opt in ArrowColorOption.allCases {
            colorPopup.addItem(withTitle: opt.label)
            colorPopup.lastItem?.tag = opt.rawValue
        }
        colorPopup.target = self
        colorPopup.action = #selector(colorChanged(_:))

        customColorWell.target = self
        customColorWell.action = #selector(customColorChanged(_:))

        fullBarCheckbox.target = self
        fullBarCheckbox.action = #selector(fullBarChanged(_:))
        alwaysHiddenCheckbox.target = self
        alwaysHiddenCheckbox.action = #selector(alwaysHiddenChanged(_:))

        let colorRow = NSStackView(views: [
            NSTextField(labelWithString: "Arrow color:"),
            colorPopup,
            customColorWell
        ])
        colorRow.orientation = .horizontal
        colorRow.spacing = 8

        let stack = NSStackView(views: [
            title,
            colorRow,
            fullBarCheckbox,
            alwaysHiddenCheckbox
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    private func loadValues() {
        colorPopup.selectItem(withTag: AppSettings.shared.arrowColorOption.rawValue)
        customColorWell.color = AppSettings.shared.customArrowColor
        customColorWell.isEnabled = (AppSettings.shared.arrowColorOption == .custom)
        fullBarCheckbox.state = AppSettings.shared.fullMenuBarMode ? .on : .off
        alwaysHiddenCheckbox.state = AppSettings.shared.enableAlwaysHiddenSection ? .on : .off
    }

    @objc private func colorChanged(_ sender: NSPopUpButton) {
        if let tag = sender.selectedItem?.tag, let opt = ArrowColorOption(rawValue: tag) {
            AppSettings.shared.arrowColorOption = opt
            customColorWell.isEnabled = (opt == .custom)
        }
    }

    @objc private func customColorChanged(_ sender: NSColorWell) {
        AppSettings.shared.customArrowColor = sender.color
        if AppSettings.shared.arrowColorOption == .custom {
            // Trigger a settings-changed notification by re-saving the option.
            AppSettings.shared.arrowColorOption = .custom
        }
    }

    @objc private func fullBarChanged(_ s: NSButton)         { AppSettings.shared.fullMenuBarMode = (s.state == .on) }
    @objc private func alwaysHiddenChanged(_ s: NSButton)    { AppSettings.shared.enableAlwaysHiddenSection = (s.state == .on) }
}

// MARK: - Shortcut

final class ShortcutPrefsView: NSView {

    private let recorder = HotKeyRecorderField()
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)

    init() {
        super.init(frame: .zero)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let title = NSTextField(labelWithString: "Global Shortcut")
        title.font = .boldSystemFont(ofSize: 16)

        let explain = NSTextField(wrappingLabelWithString:
            "Press a key combination below to toggle the hidden menu bar icons from anywhere.")
        explain.font = .systemFont(ofSize: 12)
        explain.textColor = .secondaryLabelColor

        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.widthAnchor.constraint(equalToConstant: 220).isActive = true

        clearButton.target = self
        clearButton.action = #selector(clearShortcut(_:))

        let row = NSStackView(views: [recorder, clearButton])
        row.orientation = .horizontal
        row.spacing = 8

        let stack = NSStackView(views: [title, explain, row])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    @objc private func clearShortcut(_ sender: Any?) {
        AppSettings.shared.hotKeyKeyCode = 0
        AppSettings.shared.hotKeyModifiers = 0
        HotKeyManager.shared.unregister()
        recorder.refresh()
    }
}

/// Single-field hotkey recorder. Click to focus, then press desired combo.
final class HotKeyRecorderField: NSView {

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false
    private var localMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 6

        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 28)
        ])
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        beginRecording()
    }

    func refresh() {
        let kc = AppSettings.shared.hotKeyKeyCode
        let mods = AppSettings.shared.hotKeyModifiers
        if kc == 0 {
            label.stringValue = isRecording ? "Press shortcut…" : "Click to set shortcut"
            label.textColor = .secondaryLabelColor
        } else {
            label.stringValue = HotKeyManager.displayString(keyCode: kc, modifiers: mods)
            label.textColor = .labelColor
        }
    }

    private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        refresh()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }
            if event.type == .keyDown {
                let mods = HotKeyManager.carbonModifiers(from: event.modifierFlags)
                let kc = UInt32(event.keyCode)
                // Require at least one modifier so we don't trap plain letters.
                if mods != 0 {
                    AppSettings.shared.hotKeyKeyCode = kc
                    AppSettings.shared.hotKeyModifiers = mods
                    HotKeyManager.shared.register(keyCode: kc, modifiers: mods)
                    self.endRecording()
                    return nil
                }
            }
            return event
        }
    }

    private func endRecording() {
        isRecording = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
        refresh()
    }
}

// MARK: - Advanced

final class AdvancedPrefsView: NSView {

    init() {
        super.init(frame: .zero)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let title = NSTextField(labelWithString: "Advanced")
        title.font = .boldSystemFont(ofSize: 16)

        let permButton = NSButton(title: "Open Accessibility Settings",
                                  target: self, action: #selector(openAccessibility(_:)))
        let resetLayoutButton = NSButton(title: "Reset Status Bar Layout",
                                         target: self, action: #selector(resetLayout(_:)))
        let resetButton = NSButton(title: "Reset all preferences",
                                   target: self, action: #selector(resetPrefs(_:)))

        let layoutInfo = NSTextField(wrappingLabelWithString:
            "If the arrow or vertical bar ends up in the wrong place after dragging icons around the menu bar, click Reset Status Bar Layout to put them back at their default positions.")
        layoutInfo.font = .systemFont(ofSize: 11)
        layoutInfo.textColor = .secondaryLabelColor

        let info = NSTextField(wrappingLabelWithString:
            "Quiet Menubar collects no data and makes no network calls. Accessibility permission is used only for the global keyboard shortcut.")
        info.font = .systemFont(ofSize: 11)
        info.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, permButton, resetLayoutButton, layoutInfo, resetButton, info])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    @objc private func openAccessibility(_ sender: Any?) {
        AccessibilityManager.shared.openAccessibilityPane()
    }

    @objc private func resetLayout(_ sender: Any?) {
        AppDelegate.shared?.resetStatusBarLayout()
    }

    @objc private func resetPrefs(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Reset all preferences?"
        alert.informativeText = "This restores Quiet Menubar's defaults. It does not change which icons macOS shows in the menu bar."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        }
    }
}

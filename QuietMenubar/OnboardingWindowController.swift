import AppKit

final class OnboardingWindowController: NSWindowController {

    var onDismiss: (() -> Void)?

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Welcome to Quiet Menubar"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        window.contentView = makeContentView()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(trustChanged),
                                               name: AccessibilityManager.trustChangedNotification,
                                               object: nil)
    }

    private func makeContentView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 380))

        let title = NSTextField(labelWithString: "Welcome to Quiet Menubar")
        title.font = .systemFont(ofSize: 22, weight: .bold)

        let intro = NSTextField(wrappingLabelWithString:
            "Quiet Menubar hides the icons in your menu bar that you don't want to see all the time. Here's how to use it:")
        intro.font = .systemFont(ofSize: 13)

        let steps = NSTextField(wrappingLabelWithString:
            "1. After launch you'll see two separators in the menu bar: an arrow ‹ and a vertical bar |.\n" +
            "2. Hold ⌘ and drag any menu bar icon to the LEFT of the arrow to hide it.\n" +
            "3. Icons to the RIGHT of the arrow stay always visible.\n" +
            "4. Click the arrow to show or hide your hidden icons.\n" +
            "5. Right-click the arrow or open Preferences from the | bar for more options."
        )
        steps.font = .systemFont(ofSize: 13)

        let permTitle = NSTextField(labelWithString: "Accessibility permission")
        permTitle.font = .systemFont(ofSize: 14, weight: .semibold)

        let permBody = NSTextField(wrappingLabelWithString:
            "Quiet Menubar needs Accessibility access to register a global keyboard shortcut. We do not read your screen, your input, or any other data. No telemetry. No network."
        )
        permBody.font = .systemFont(ofSize: 12)
        permBody.textColor = .secondaryLabelColor

        let openButton = NSButton(title: "Open Accessibility Settings",
                                  target: self, action: #selector(openSettings(_:)))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"

        let skipButton = NSButton(title: "Skip for now",
                                  target: self, action: #selector(dismiss(_:)))

        let buttons = NSStackView(views: [skipButton, openButton])
        buttons.orientation = .horizontal
        buttons.spacing = 12

        let stack = NSStackView(views: [title, intro, steps, permTitle, permBody, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24)
        ])
        return container
    }

    @objc private func openSettings(_ sender: Any?) {
        AccessibilityManager.shared.promptForTrust()
        AccessibilityManager.shared.openAccessibilityPane()
    }

    @objc private func dismiss(_ sender: Any?) {
        AppSettings.shared.hasOnboarded = true
        close()
        onDismiss?()
    }

    @objc private func trustChanged() {
        if AccessibilityManager.shared.isTrusted() {
            AppSettings.shared.hasOnboarded = true
            close()
            onDismiss?()
        }
    }
}

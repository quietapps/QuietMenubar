import Foundation
import AppKit

enum AutoHideDelay: Int, CaseIterable, Identifiable {
    case never = 0
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case sixtySeconds = 60

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .never: return "Never"
        case .fiveSeconds: return "After 5 seconds"
        case .tenSeconds: return "After 10 seconds"
        case .fifteenSeconds: return "After 15 seconds"
        case .thirtySeconds: return "After 30 seconds"
        case .sixtySeconds: return "After 60 seconds"
        }
    }
}

enum ArrowColorOption: Int, CaseIterable {
    case systemLabel = 0
    case white = 1
    case black = 2
    case menubarBlend = 3
    case custom = 4

    var label: String {
        switch self {
        case .systemLabel: return "System (auto)"
        case .white: return "White"
        case .black: return "Black"
        case .menubarBlend: return "Blend with menu bar"
        case .custom: return "Custom…"
        }
    }
}

final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let autoHideDelay = "autoHideDelay"
        static let newIconsAlwaysVisible = "newIconsAlwaysVisible"
        static let arrowColorOption = "arrowColorOption"
        static let customArrowColor = "customArrowColor"
        static let fullMenuBarMode = "fullMenuBarMode"
        static let enableAlwaysHiddenSection = "enableAlwaysHiddenSection"
        static let launchAtLogin = "launchAtLogin"
        static let hotKeyKeyCode = "hotKeyKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let hasOnboarded = "hasOnboarded"
        static let alwaysHiddenCollapsed = "alwaysHiddenCollapsed"
    }

    private init() {
        defaults.register(defaults: [
            Key.autoHideDelay: AutoHideDelay.never.rawValue,
            Key.newIconsAlwaysVisible: true,
            Key.arrowColorOption: ArrowColorOption.systemLabel.rawValue,
            Key.fullMenuBarMode: false,
            Key.enableAlwaysHiddenSection: false,
            Key.launchAtLogin: false,
            Key.hasOnboarded: false,
            Key.alwaysHiddenCollapsed: false
        ])
    }

    var autoHideDelay: AutoHideDelay {
        get { AutoHideDelay(rawValue: defaults.integer(forKey: Key.autoHideDelay)) ?? .never }
        set { defaults.set(newValue.rawValue, forKey: Key.autoHideDelay) }
    }

    var newIconsAlwaysVisible: Bool {
        get { defaults.bool(forKey: Key.newIconsAlwaysVisible) }
        set { defaults.set(newValue, forKey: Key.newIconsAlwaysVisible) }
    }

    var arrowColorOption: ArrowColorOption {
        get { ArrowColorOption(rawValue: defaults.integer(forKey: Key.arrowColorOption)) ?? .systemLabel }
        set { defaults.set(newValue.rawValue, forKey: Key.arrowColorOption) }
    }

    var customArrowColor: NSColor {
        get {
            if let data = defaults.data(forKey: Key.customArrowColor),
               let c = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return c
            }
            return .labelColor
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: Key.customArrowColor)
            }
        }
    }

    var fullMenuBarMode: Bool {
        get { defaults.bool(forKey: Key.fullMenuBarMode) }
        set { defaults.set(newValue, forKey: Key.fullMenuBarMode) }
    }

    var enableAlwaysHiddenSection: Bool {
        get { defaults.bool(forKey: Key.enableAlwaysHiddenSection) }
        set { defaults.set(newValue, forKey: Key.enableAlwaysHiddenSection) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    var hotKeyKeyCode: UInt32 {
        get { UInt32(defaults.integer(forKey: Key.hotKeyKeyCode)) }
        set { defaults.set(Int(newValue), forKey: Key.hotKeyKeyCode) }
    }

    var hotKeyModifiers: UInt32 {
        get { UInt32(defaults.integer(forKey: Key.hotKeyModifiers)) }
        set { defaults.set(Int(newValue), forKey: Key.hotKeyModifiers) }
    }

    var hasOnboarded: Bool {
        get { defaults.bool(forKey: Key.hasOnboarded) }
        set { defaults.set(newValue, forKey: Key.hasOnboarded) }
    }

    var alwaysHiddenCollapsed: Bool {
        get { defaults.bool(forKey: Key.alwaysHiddenCollapsed) }
        set { defaults.set(newValue, forKey: Key.alwaysHiddenCollapsed) }
    }
}

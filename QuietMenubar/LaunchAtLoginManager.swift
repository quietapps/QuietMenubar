import Foundation
import ServiceManagement

/// Wraps SMAppService (macOS 13+) with a graceful fallback for macOS 12.
/// On macOS 12 we fall back to SMLoginItemSetEnabled which requires a separate helper bundle;
/// to keep the project single-target we surface a clear "unsupported on this OS" error there
/// and let the README explain how to add a LoginItem helper if 12 support is required.
enum LaunchAtLoginManager {

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled { return true }
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return true
            } catch {
                NSLog("QuietMenubar: SMAppService failed: \(error.localizedDescription)")
                return false
            }
        } else {
            // macOS 12: SMLoginItemSetEnabled requires a packaged LoginItem helper bundle.
            // This single-target project does not ship one — treat as no-op + log.
            NSLog("QuietMenubar: launch-at-login on macOS 12 requires a helper bundle; skipping.")
            return false
        }
    }
}

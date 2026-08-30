import Foundation
import ServiceManagement

/// Thin wrapper over SMAppService (no LaunchAgent fallback — v1 keeps it
/// simple; the Timer app's fallback can be ported if registration ever
/// lands dead here too).
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return loc("Aktiv", "Active")
        case .requiresApproval:
            return loc("Wartet auf Freigabe in den Systemeinstellungen", "Waiting for approval in System Settings")
        default:
            return loc("Inaktiv", "Inactive")
        }
    }

    /// Errors are swallowed into the status line (bare `swift run`
    /// binaries without a bundle cannot register — expected).
    static func setEnabled(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

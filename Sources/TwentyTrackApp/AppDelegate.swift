import AppKit
import TwentyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let calendar = Calendar.current
        let preferences = Preferences()
        let dayStore = DayStore(directory: DayStore.defaultDirectory(), calendar: calendar)
        let usageStore = AppUsageStore(
            directory: AppUsageStore.defaultDirectory(), calendar: calendar
        )
        let usageTracker = AppUsageTracker(store: usageStore, preferences: preferences)
        statusBarController = StatusBarController(
            preferences: preferences, dayStore: dayStore,
            usageStore: usageStore, usageTracker: usageTracker, calendar: calendar
        )
    }

    // Targets of the app menu / status item menu shortcuts (nil-targeted
    // actions reach the app delegate through the responder chain).
    @objc func openStatistics(_ sender: Any?) { statusBarController?.openStatistics() }
    @objc func openSettings(_ sender: Any?) { statusBarController?.openSettings() }
    @objc func togglePause(_ sender: Any?) { statusBarController?.togglePause() }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.prepareForTermination()
    }
}

/// Statistics (⌘I) / Settings (⌘,) / Pause (deliberately no shortcut —
/// like ⌘Q, a reflexive keystroke must never stop tracking) — shared by the
/// hidden app menu (where the shortcuts live) and the status item menu.
enum AppMenuActions {
    static func items(paused: Bool) -> [(String, Selector, String)] {
        [
            (loc("Statistik", "Statistics"), #selector(AppDelegate.openStatistics(_:)), "i"),
            (loc("Einstellungen…", "Settings…"), #selector(AppDelegate.openSettings(_:)), ","),
            (paused ? loc("Tracking fortsetzen", "Resume tracking") : loc("Tracking pausieren", "Pause tracking"),
             #selector(AppDelegate.togglePause(_:)), ""),
        ]
    }
}

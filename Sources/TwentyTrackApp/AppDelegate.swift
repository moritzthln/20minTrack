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

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.prepareForTermination()
    }
}

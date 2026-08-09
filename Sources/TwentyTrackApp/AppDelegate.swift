import AppKit
import TwentyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let calendar = Calendar.current
        let preferences = Preferences()
        let dayStore = DayStore(directory: DayStore.defaultDirectory(), calendar: calendar)
        statusBarController = StatusBarController(
            preferences: preferences, dayStore: dayStore, calendar: calendar
        )
    }
}

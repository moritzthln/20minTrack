import AppKit
import SwiftUI
import TwentyCore

final class StatsWindowController {
    private var window: NSWindow?
    private let dayStore: DayStore
    private let preferences: Preferences
    private let calendar: Calendar
    private let usageFor: (DateInterval) -> [AppUsageTotal]

    init(
        dayStore: DayStore, preferences: Preferences, calendar: Calendar,
        usageFor: @escaping (DateInterval) -> [AppUsageTotal]
    ) {
        self.dayStore = dayStore
        self.preferences = preferences
        self.calendar = calendar
        self.usageFor = usageFor
    }

    func show() {
        if window == nil {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            created.title = loc("Statistik", "Statistics")
            created.isReleasedWhenClosed = false
            created.minSize = NSSize(width: 480, height: 540)
            created.setFrameAutosaveName("StatsWindow")
            created.center()
            window = created
        }
        // Fresh view on every open so the numbers reload (Timer pattern).
        window?.contentView = NSHostingView(rootView: StatsView(
            dayStore: dayStore, preferences: preferences,
            calendar: calendar, usageFor: usageFor
        ))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

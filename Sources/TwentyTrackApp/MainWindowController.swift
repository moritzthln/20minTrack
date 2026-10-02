import AppKit
import SwiftUI
import TwentyCore

/// One window for Statistics and Settings, switched by toolbar tabs
/// (the standard macOS preferences pattern). Closing it closes both —
/// no Settings window is ever left behind by closing Statistics.
final class MainWindowController {
    enum Tab: Int {
        case statistics = 0
        case settings = 1
    }

    private var window: NSWindow?
    private var tabs: NSTabViewController?
    private let statsHost: NSHostingController<StatsView>
    private let settingsHost: NSHostingController<SettingsView>
    private let makeStats: () -> StatsView
    private let preferences: Preferences

    init(preferences: Preferences, makeStats: @escaping () -> StatsView) {
        self.preferences = preferences
        self.makeStats = makeStats
        self.statsHost = NSHostingController(rootView: makeStats())
        self.settingsHost = NSHostingController(rootView: SettingsView(preferences: preferences))
    }

    func show(_ tab: Tab) {
        // Fresh views on every open so numbers and stored values reload.
        statsHost.rootView = makeStats()
        settingsHost.rootView = SettingsView(preferences: preferences)
        let window = ensureWindow()
        tabs?.selectedTabViewItemIndex = tab.rawValue
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(item(
            statsHost, title: loc("Statistik", "Statistics"), symbol: "chart.bar.xaxis"
        ))
        tabs.addTabViewItem(item(
            settingsHost, title: loc("Einstellungen", "Settings"), symbol: "gearshape"
        ))
        let created = NSWindow(contentViewController: tabs)
        created.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        created.toolbarStyle = .preference
        created.isReleasedWhenClosed = false
        created.minSize = NSSize(width: 480, height: 540)
        created.setContentSize(NSSize(width: 540, height: 680))
        created.center()
        created.setFrameAutosaveName("MainWindow")
        self.tabs = tabs
        window = created
        return created
    }

    private func item(_ controller: NSViewController, title: String, symbol: String) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}

import AppKit
import SwiftUI
import TwentyCore

final class SettingsWindowController {
    private var window: NSWindow?
    private let preferences: Preferences

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    func show() {
        if window == nil {
            let created = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            created.title = "Einstellungen"
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        // Fresh view on every open so the stored values reload.
        window?.contentView = NSHostingView(rootView: SettingsView(preferences: preferences))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

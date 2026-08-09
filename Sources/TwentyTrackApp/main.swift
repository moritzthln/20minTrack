import AppKit

// Duplicate-instance guard (Timer pattern): login item plus manual launch
// must not produce two trackers. Bare binaries (swift run) have no bundle
// identifier and skip the check.
if let bundleID = Bundle.main.bundleIdentifier {
    let ownPID = ProcessInfo.processInfo.processIdentifier
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .filter { $0.processIdentifier != ownPID }
    if !others.isEmpty {
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// Hidden main menu. Deliberately NO ⌘Q shortcut: a reflexive ⌘Q while
// the check-in window is key must never kill the tracker. Quitting works
// via the popover "…" menu and the status item's right-click menu.
let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
let appMenu = NSMenu()
appMenu.addItem(
    NSMenuItem(
        title: "20minTrack beenden",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: ""
    )
)
appMenuItem.submenu = appMenu
mainMenu.addItem(appMenuItem)
app.mainMenu = mainMenu

app.run()

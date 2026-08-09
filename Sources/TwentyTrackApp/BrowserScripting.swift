import Foundation
import TwentyCore

/// Reads the frontmost browser's active tab URL via AppleScript (Timer
/// port, read-only subset). Needs the per-browser macOS automation
/// permission — the prompt appears on first use with the browser
/// frontmost; on denial or scripting errors everything silently falls
/// back to plain app segments.
enum BrowserScripting {
    static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser", // Arc
    ]

    static func isBrowser(_ bundleID: String) -> Bool {
        browserBundleIDs.contains(bundleID)
    }

    /// Host of the active tab, lowercased, one leading "www." stripped;
    /// nil on scripting failure or internal pages.
    static func activeTabDomain(bundleID: String) -> String? {
        guard let source = urlScript(bundleID: bundleID),
              let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil,
              let urlString = result.stringValue,
              let host = URL(string: urlString)?.host?.lowercased() else { return nil }
        let stripped = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return stripped.isEmpty ? nil : stripped
    }

    private static func urlScript(bundleID: String) -> String? {
        switch bundleID {
        case "com.apple.Safari":
            return #"tell application "Safari" to return URL of current tab of front window"#
        case "com.google.Chrome":
            return #"tell application "Google Chrome" to return URL of active tab of front window"#
        case "company.thebrowser.Browser":
            return #"tell application "Arc" to return URL of active tab of front window"#
        default:
            return nil
        }
    }
}

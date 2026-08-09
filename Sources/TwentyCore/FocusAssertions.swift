import Foundation

/// Parses the content of ~/Library/DoNotDisturb/DB/Assertions.json —
/// macOS keeps one store assertion record per active Focus mode there.
/// Unreadable or unexpected data reads as "not active" (fail open:
/// better to prompt than to silently stop prompting forever).
public enum FocusAssertions {
    public static func isActive(json: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let data = root["data"] as? [[String: Any]] else {
            return false
        }
        return data.contains { entry in
            guard let records = entry["storeAssertionRecords"] as? [Any] else { return false }
            return !records.isEmpty
        }
    }
}

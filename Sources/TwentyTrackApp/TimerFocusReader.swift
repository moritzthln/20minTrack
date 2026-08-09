import Foundation
import TwentyCore

/// Reads the Timer app's local focus interval log
/// (~/Library/Application Support/Timer/focus/YYYY-MM-DD.json) — the data
/// behind the "a focus session ran, preselect Fokus Arbeit" suggestion.
/// Missing files (Timer not installed / no sessions) read as empty.
enum TimerFocusReader {
    private struct FocusInterval: Codable {
        let start: Date
        let end: Date
    }

    /// Focus intervals overlapping the given range (range spans at most
    /// two adjacent days).
    static func intervals(in range: DateInterval, calendar: Calendar) -> [DateInterval] {
        var days = [range.start]
        if !calendar.isDate(range.start, inSameDayAs: range.end) {
            days.append(range.end)
        }
        return days.flatMap { load(day: $0) }
            .map { DateInterval(start: $0.start, end: $0.end) }
            .filter { $0.end > range.start && $0.start < range.end }
    }

    private static func load(day: Date) -> [FocusInterval] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        let url = base.appendingPathComponent("Timer/focus/\(formatter.string(from: day)).json")
        guard let data = try? Data(contentsOf: url),
              let intervals = try? JSONDecoder().decode([FocusInterval].self, from: data) else {
            return []
        }
        return intervals
    }
}

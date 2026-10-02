import Foundation

/// A calendar event reduced to what the check-in needs — EventKit-free,
/// so the selection rules stay testable.
public struct CalendarEventInfo: Equatable {
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarID: String

    public init(title: String, start: Date, end: Date, isAllDay: Bool, calendarID: String) {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
    }
}

/// Which calendar events to show next to a block as a memory aid. A hint
/// only — events never create or change entries.
public enum CalendarHints {
    public static let maxHints = 5

    /// Timed events overlapping `range` (all-day events say nothing about a
    /// 20-minute block), limited to `calendarIDs` unless that set is empty,
    /// sorted by start, duplicates (same title + start, e.g. an invite in
    /// two calendars) removed, capped at `maxHints`.
    public static func events(
        _ events: [CalendarEventInfo], overlapping range: DateInterval, calendarIDs: Set<String>
    ) -> [CalendarEventInfo] {
        var seen = Set<String>()
        return events
            .filter { !$0.isAllDay && $0.end > range.start && $0.start < range.end }
            .filter { calendarIDs.isEmpty || calendarIDs.contains($0.calendarID) }
            .sorted { $0.start < $1.start }
            .filter { seen.insert("\($0.title)|\($0.start.timeIntervalSinceReferenceDate)").inserted }
            .prefix(maxHints)
            .map { $0 }
    }
}

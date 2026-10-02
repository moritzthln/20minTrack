import Foundation
import TwentyCore

func runCalendarHintsTests() {
    let range = DateInterval(start: makeDate(2026, 10, 2, 14, 0), end: makeDate(2026, 10, 2, 14, 40))
    func event(
        _ title: String, _ start: (Int, Int), _ end: (Int, Int),
        allDay: Bool = false, calendar: String = "work"
    ) -> CalendarEventInfo {
        CalendarEventInfo(
            title: title,
            start: makeDate(2026, 10, 2, start.0, start.1),
            end: makeDate(2026, 10, 2, end.0, end.1),
            isAllDay: allDay, calendarID: calendar
        )
    }

    test("only events overlapping the range, sorted by start") {
        let events = [
            event("Later", (15, 0), (16, 0)),
            event("Standup", (14, 20), (14, 30)),
            event("Lunch", (12, 0), (14, 10)),
            event("Ends at start", (13, 0), (14, 0)),
        ]
        let hints = CalendarHints.events(events, overlapping: range, calendarIDs: [])
        try expectEqual(hints.map(\.title), ["Lunch", "Standup"])
    }

    test("all-day events are skipped — they say nothing about a block") {
        let hints = CalendarHints.events(
            [event("Holiday", (0, 0), (23, 59), allDay: true), event("Call", (14, 0), (14, 20))],
            overlapping: range, calendarIDs: []
        )
        try expectEqual(hints.map(\.title), ["Call"])
    }

    test("calendar filter: empty = all, otherwise only the chosen calendars") {
        let events = [event("Work call", (14, 0), (14, 20)), event("Gym", (14, 20), (14, 40), calendar: "private")]
        try expectEqual(CalendarHints.events(events, overlapping: range, calendarIDs: []).count, 2)
        try expectEqual(
            CalendarHints.events(events, overlapping: range, calendarIDs: ["private"]).map(\.title),
            ["Gym"]
        )
    }

    test("duplicates (same title and start, e.g. shared calendars) appear once; capped at 5") {
        var events = [event("Sync", (14, 0), (14, 30)), event("Sync", (14, 0), (14, 30), calendar: "shared")]
        for minute in stride(from: 0, to: 40, by: 5) {
            events.append(event("Slot \(minute)", (14, minute), (14, minute + 5)))
        }
        let hints = CalendarHints.events(events, overlapping: range, calendarIDs: [])
        try expectEqual(hints.filter { $0.title == "Sync" }.count, 1)
        try expectEqual(hints.count, CalendarHints.maxHints)
    }
}

func runCalendarPreferencesTests() {
    test("calendar hints default off with all calendars, and roundtrip") {
        let suite = "20minTrack-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        try expect(!prefs.calendarHintsEnabled, "off by default — opt-in")
        try expect(prefs.calendarIDs.isEmpty, "empty = all calendars")
        prefs.calendarHintsEnabled = true
        prefs.calendarIDs = ["a", "b"]
        try expect(prefs.calendarHintsEnabled, "enabled")
        try expectEqual(prefs.calendarIDs, ["a", "b"])
    }
}

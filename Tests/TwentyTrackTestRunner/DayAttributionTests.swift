import Foundation
import TwentyCore

private let now = makeDate(2026, 8, 18, 12, 0)

private func entries(_ day: Int, hours: Int) -> [Entry] {
    [Entry(
        start: makeDate(2026, 8, day, 9, 0), end: makeDate(2026, 8, day, 9 + hours, 0),
        labelID: "focus-mma", text: ""
    )]
}

func runDayAttributionTests() {
    test("today and yesterday are not settled, older days are") {
        try expect(!DayAttribution.isSettled(
            day: makeDate(2026, 8, 18, 8, 0), now: now, calendar: testCalendar
        ), "today")
        try expect(!DayAttribution.isSettled(
            day: makeDate(2026, 8, 17, 8, 0), now: now, calendar: testCalendar
        ), "yesterday")
        try expect(DayAttribution.isSettled(
            day: makeDate(2026, 8, 16, 8, 0), now: now, calendar: testCalendar
        ), "day before yesterday")
    }

    test("gaps on a settled day count as distraction") {
        let result = DayAttribution.totals(
            day: makeDate(2026, 8, 16, 0, 0), entries: entries(16, hours: 4),
            now: now, calendar: testCalendar, distractionLabelID: "no-focus"
        )
        try expectEqual(result.untracked, 0, accuracy: 0.5)
        try expectEqual(result.totals["focus-mma"], 4 * 3600)
        try expectEqual(result.totals["no-focus"], 20 * 3600, "24 h minus 4 h tracked")
    }

    test("gaps on yesterday stay untracked") {
        let result = DayAttribution.totals(
            day: makeDate(2026, 8, 17, 0, 0), entries: entries(17, hours: 4),
            now: now, calendar: testCalendar, distractionLabelID: "no-focus"
        )
        try expectEqual(result.untracked, 20 * 3600, accuracy: 0.5)
        try expectNil(result.totals["no-focus"])
    }

    test("an empty settled day is never attributed") {
        let result = DayAttribution.totals(
            day: makeDate(2026, 8, 10, 0, 0), entries: [],
            now: now, calendar: testCalendar, distractionLabelID: "no-focus"
        )
        try expectEqual(result.untracked, 24 * 3600, accuracy: 0.5)
        try expect(result.totals.isEmpty, "no totals for an empty day")
    }

    test("an absent settled day keeps its gaps out of distraction") {
        let result = DayAttribution.totals(
            day: makeDate(2026, 8, 16, 0, 0), entries: entries(16, hours: 2),
            now: now, calendar: testCalendar, distractionLabelID: "no-focus",
            isAbsent: true
        )
        try expectEqual(result.untracked, 22 * 3600, accuracy: 0.5)
        try expectNil(result.totals["no-focus"])
    }

    test("a fully tracked settled day adds nothing") {
        let full = [Entry(
            start: makeDate(2026, 8, 16, 0, 0), end: makeDate(2026, 8, 17, 0, 0),
            labelID: "sleep", text: ""
        )]
        let result = DayAttribution.totals(
            day: makeDate(2026, 8, 16, 0, 0), entries: full,
            now: now, calendar: testCalendar, distractionLabelID: "no-focus"
        )
        try expectEqual(result.untracked, 0, accuracy: 0.5)
        try expectNil(result.totals["no-focus"])
    }
}

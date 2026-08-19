import Foundation
import TwentyCore

private let vacation = Absence(
    name: "Urlaub",
    startDay: makeDate(2026, 8, 20, 0, 0),
    endDay: makeDate(2026, 8, 24, 0, 0)
)

func runAbsenceRulesTests() {
    test("absence bounds are inclusive per day") {
        try expect(!AbsenceRules.isAbsent(
            day: makeDate(2026, 8, 19, 23, 0), in: [vacation], calendar: testCalendar
        ), "day before")
        try expect(AbsenceRules.isAbsent(
            day: makeDate(2026, 8, 20, 0, 0), in: [vacation], calendar: testCalendar
        ), "first day")
        try expect(AbsenceRules.isAbsent(
            day: makeDate(2026, 8, 24, 23, 59), in: [vacation], calendar: testCalendar
        ), "last day")
        try expect(!AbsenceRules.isAbsent(
            day: makeDate(2026, 8, 25, 0, 0), in: [vacation], calendar: testCalendar
        ), "day after")
    }

    test("anchor inside an absence jumps to the midnight after it") {
        let anchor = makeDate(2026, 8, 21, 14, 20)
        try expectEqual(
            AbsenceRules.normalizedAnchor(anchor, absences: [vacation], calendar: testCalendar),
            makeDate(2026, 8, 25, 0, 0)
        )
    }

    test("chained absences are walked through") {
        let second = Absence(
            name: "Reise",
            startDay: makeDate(2026, 8, 25, 0, 0),
            endDay: makeDate(2026, 8, 26, 0, 0)
        )
        try expectEqual(
            AbsenceRules.normalizedAnchor(
                makeDate(2026, 8, 20, 8, 0), absences: [vacation, second], calendar: testCalendar
            ),
            makeDate(2026, 8, 27, 0, 0)
        )
    }

    test("an anchor outside any absence stays put") {
        let anchor = makeDate(2026, 8, 18, 10, 0)
        try expectEqual(
            AbsenceRules.normalizedAnchor(anchor, absences: [vacation], calendar: testCalendar),
            anchor
        )
    }
}

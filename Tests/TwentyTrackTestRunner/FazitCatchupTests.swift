import Foundation
import TwentyCore

func runFazitCatchupTests() {
    let evening = 1290  // 21:30

    func due(
        _ now: Date, hasFazit: Bool = false, hasEntries: Bool = true,
        absences: [Absence] = []
    ) -> Date? {
        FazitCatchup.dueDay(
            now: now, calendar: testCalendar,
            yesterdayHasFazit: hasFazit, yesterdayHasEntries: hasEntries,
            eveningPromptMinute: evening, absences: absences
        )
    }

    test("catchup window opens at 09:30 and closes at the evening prompt") {
        try expectNil(due(makeDate(2026, 9, 2, 9, 29)))
        try expectEqual(due(makeDate(2026, 9, 2, 9, 30)), makeDate(2026, 9, 2, 0, 0).addingTimeInterval(-86400))
        try expectEqual(due(makeDate(2026, 9, 2, 21, 29)), makeDate(2026, 9, 1, 0, 0))
        try expectNil(due(makeDate(2026, 9, 2, 21, 30)), "evening prompt takes over")
    }

    test("no catchup once yesterday has a Fazit") {
        try expectNil(due(makeDate(2026, 9, 2, 10, 0), hasFazit: true))
    }

    test("no catchup for a day without any entries") {
        try expectNil(due(makeDate(2026, 9, 2, 10, 0), hasEntries: false))
    }

    test("absent days never prompt — yesterday or today") {
        let yesterdayOff = Absence(
            name: "Urlaub",
            startDay: makeDate(2026, 9, 1, 0, 0), endDay: makeDate(2026, 9, 1, 0, 0)
        )
        let todayOff = Absence(
            name: "Urlaub",
            startDay: makeDate(2026, 9, 2, 0, 0), endDay: makeDate(2026, 9, 2, 0, 0)
        )
        try expectNil(due(makeDate(2026, 9, 2, 10, 0), absences: [yesterdayOff]))
        try expectNil(due(makeDate(2026, 9, 2, 10, 0), absences: [todayOff]))
        try expectEqual(
            due(makeDate(2026, 9, 2, 10, 0)), makeDate(2026, 9, 1, 0, 0),
            "no absence, catchup due"
        )
    }
}

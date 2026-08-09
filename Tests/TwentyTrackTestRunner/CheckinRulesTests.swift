import Foundation
import TwentyCore

func runCheckinRulesTests() {
    test("nil anchor means nothing is pending") {
        try expectNil(CheckinRules.pendingRange(
            anchor: nil, now: makeDate(2026, 8, 9, 10, 45), calendar: testCalendar
        ))
    }

    test("anchor at the current block start means nothing is pending") {
        try expectNil(CheckinRules.pendingRange(
            anchor: makeDate(2026, 8, 9, 10, 0),
            now: makeDate(2026, 8, 9, 10, 19), calendar: testCalendar
        ))
    }

    test("pending range ends at the last completed boundary") {
        let range = CheckinRules.pendingRange(
            anchor: makeDate(2026, 8, 9, 10, 0),
            now: makeDate(2026, 8, 9, 10, 45), calendar: testCalendar
        )
        try expectEqual(range?.start, makeDate(2026, 8, 9, 10, 0))
        try expectEqual(range?.end, makeDate(2026, 8, 9, 10, 40))
    }

    test("overnight gap is fully pending") {
        let range = CheckinRules.pendingRange(
            anchor: makeDate(2026, 8, 8, 23, 40),
            now: makeDate(2026, 8, 9, 7, 35), calendar: testCalendar
        )
        try expectEqual(range?.start, makeDate(2026, 8, 8, 23, 40))
        try expectEqual(range?.end, makeDate(2026, 8, 9, 7, 20))
    }

    test("lookback is capped at the start of yesterday") {
        let range = CheckinRules.pendingRange(
            anchor: makeDate(2026, 8, 5, 9, 0),
            now: makeDate(2026, 8, 9, 10, 5), calendar: testCalendar
        )
        try expectEqual(range?.start, makeDate(2026, 8, 8, 0, 0))
        try expectEqual(range?.end, makeDate(2026, 8, 9, 10, 0))
    }

    test("future anchor yields nothing") {
        try expectNil(CheckinRules.pendingRange(
            anchor: makeDate(2026, 8, 9, 10, 40),
            now: makeDate(2026, 8, 9, 10, 5), calendar: testCalendar
        ))
    }
}

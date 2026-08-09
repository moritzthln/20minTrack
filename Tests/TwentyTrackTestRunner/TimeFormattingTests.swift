import Foundation
import TwentyCore

func runTimeFormattingTests() {
    test("wording renders minutes below an hour") {
        try expectEqual(TimeFormatting.wording(seconds: 45 * 60), "45 min")
        try expectEqual(TimeFormatting.wording(seconds: 0), "0 min")
    }

    test("wording renders hours with remaining minutes") {
        try expectEqual(TimeFormatting.wording(seconds: 85 * 60), "1 h 25 min")
        try expectEqual(TimeFormatting.wording(seconds: 2 * 3600), "2 h")
    }

    test("clock renders 24h wall time") {
        try expectEqual(
            TimeFormatting.clock(makeDate(2026, 8, 9, 9, 5), calendar: testCalendar),
            "09:05"
        )
        try expectEqual(
            TimeFormatting.clock(makeDate(2026, 8, 9, 23, 40), calendar: testCalendar),
            "23:40"
        )
    }
}

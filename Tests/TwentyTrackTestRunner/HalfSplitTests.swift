import Foundation
import TwentyCore

func runHalfSplitTests() {
    test("one block splits into 10 + 10 minutes") {
        let pairs = HalfSplit.halves(
            of: DateInterval(
                start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20)
            ),
            calendar: testCalendar
        )
        try expectEqual(pairs.count, 1)
        try expectEqual(pairs[0].first.end, makeDate(2026, 8, 9, 10, 10))
        try expectEqual(pairs[0].second.start, makeDate(2026, 8, 9, 10, 10))
        try expectEqual(pairs[0].second.end, makeDate(2026, 8, 9, 10, 20))
    }

    test("every block of a longer span is halved") {
        let pairs = HalfSplit.halves(
            of: DateInterval(
                start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 11, 0)
            ),
            calendar: testCalendar
        )
        try expectEqual(pairs.count, 3)
        try expectEqual(pairs[1].first.start, makeDate(2026, 8, 9, 10, 20))
        try expectEqual(pairs[1].first.end, makeDate(2026, 8, 9, 10, 30))
        try expectEqual(pairs[2].second.end, makeDate(2026, 8, 9, 11, 0))
        let firstTotal = pairs.reduce(0.0) { $0 + $1.first.duration }
        let secondTotal = pairs.reduce(0.0) { $0 + $1.second.duration }
        try expectEqual(firstTotal, secondTotal, accuracy: 0.5, "50/50 split")
    }

    test("a partial block is halved at its own midpoint") {
        let pairs = HalfSplit.halves(
            of: DateInterval(
                start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 10)
            ),
            calendar: testCalendar
        )
        try expectEqual(pairs.count, 1)
        try expectEqual(pairs[0].first.end, makeDate(2026, 8, 9, 10, 5))
    }

    test("an empty span yields nothing") {
        try expectEqual(
            HalfSplit.halves(
                of: DateInterval(
                    start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 0)
                ),
                calendar: testCalendar
            ).count,
            0
        )
    }
}

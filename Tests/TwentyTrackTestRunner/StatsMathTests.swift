import Foundation
import TwentyCore

private func entry(_ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int, _ label: String) -> Entry {
    Entry(
        start: makeDate(2026, 8, 9, h1, m1), end: makeDate(2026, 8, 9, h2, m2),
        labelID: label, text: ""
    )
}

func runStatsMathTests() {
    test("totals sums seconds per label") {
        let totals = StatsMath.totals([
            entry(9, 0, 10, 0, "focus-mma"),
            entry(10, 0, 10, 20, "orga"),
            entry(11, 0, 11, 40, "focus-mma"),
        ])
        try expectEqual(totals["focus-mma"], 6000, "60 + 40 min")
        try expectEqual(totals["orga"], 1200)
        try expectNil(totals["sport"])
    }

    test("trackedSeconds sums all entries") {
        try expectEqual(
            StatsMath.trackedSeconds([entry(9, 0, 10, 0, "a"), entry(12, 0, 12, 20, "b")]),
            4800
        )
    }

    test("untrackedSeconds for a past day is the full day minus tracked") {
        let value = StatsMath.untrackedSeconds(
            day: makeDate(2026, 8, 8, 12, 0),
            reference: makeDate(2026, 8, 9, 9, 0),
            entries: [Entry(
                start: makeDate(2026, 8, 8, 9, 0), end: makeDate(2026, 8, 8, 10, 0),
                labelID: "a", text: ""
            )],
            calendar: testCalendar
        )
        try expectEqual(value, 86400 - 3600, accuracy: 0.5)
    }

    test("untrackedSeconds for today only counts elapsed time") {
        let value = StatsMath.untrackedSeconds(
            day: makeDate(2026, 8, 9, 0, 0),
            reference: makeDate(2026, 8, 9, 10, 0),
            entries: [entry(9, 0, 10, 0, "a")],
            calendar: testCalendar
        )
        try expectEqual(value, 9 * 3600, accuracy: 0.5)
    }

    test("untrackedSeconds never goes negative") {
        let value = StatsMath.untrackedSeconds(
            day: makeDate(2026, 8, 9, 0, 0),
            reference: makeDate(2026, 8, 9, 0, 10),
            entries: [entry(0, 0, 1, 0, "a")],
            calendar: testCalendar
        )
        try expectEqual(value, 0, accuracy: 0.5)
    }

    test("percentLabel renders German-style whole percents") {
        try expectEqual(StatsMath.percentLabel(seconds: 3900, total: 10000), "39 %")
        try expectEqual(StatsMath.percentLabel(seconds: 25, total: 10000), "<1 %")
        try expectEqual(StatsMath.percentLabel(seconds: 50, total: 10000), "1 %", "halves round up")
        try expectNil(StatsMath.percentLabel(seconds: 0, total: 10000))
        try expectNil(StatsMath.percentLabel(seconds: 100, total: 0))
    }

    test("weekDays returns the ISO week Monday through Sunday") {
        let days = StatsMath.weekDays(
            containing: makeDate(2026, 8, 9, 15, 0), calendar: testCalendar
        )
        try expectEqual(days.count, 7)
        try expectEqual(days.first, makeDate(2026, 8, 3, 0, 0), "Monday")
        try expectEqual(days.last, makeDate(2026, 8, 9, 0, 0), "Sunday")
    }
}

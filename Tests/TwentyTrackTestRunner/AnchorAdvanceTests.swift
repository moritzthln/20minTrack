import Foundation
import TwentyCore

private func entry(_ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int) -> Entry {
    Entry(
        start: makeDate(2026, 8, 9, h1, m1), end: makeDate(2026, 8, 9, h2, m2),
        labelID: "orga", text: ""
    )
}

func runAnchorAdvanceTests() {
    let limit = makeDate(2026, 8, 9, 12, 0)

    test("no coverage leaves the anchor unchanged") {
        try expectEqual(
            AnchorAdvance.advanced(
                from: makeDate(2026, 8, 9, 10, 0), upTo: limit,
                entries: [], calendar: testCalendar
            ),
            makeDate(2026, 8, 9, 10, 0)
        )
    }

    test("a fully covered first block advances one block") {
        try expectEqual(
            AnchorAdvance.advanced(
                from: makeDate(2026, 8, 9, 10, 0), upTo: limit,
                entries: [entry(10, 0, 10, 20)], calendar: testCalendar
            ),
            makeDate(2026, 8, 9, 10, 20)
        )
    }

    test("adjoining entries advance across blocks") {
        try expectEqual(
            AnchorAdvance.advanced(
                from: makeDate(2026, 8, 9, 10, 0), upTo: limit,
                entries: [entry(10, 0, 10, 20), entry(10, 20, 11, 0)], calendar: testCalendar
            ),
            makeDate(2026, 8, 9, 11, 0)
        )
    }

    test("a block covered by two touching pieces counts as covered") {
        try expectEqual(
            AnchorAdvance.advanced(
                from: makeDate(2026, 8, 9, 10, 0), upTo: limit,
                entries: [entry(10, 0, 10, 12), entry(10, 12, 10, 20)], calendar: testCalendar
            ),
            makeDate(2026, 8, 9, 10, 20)
        )
    }

    test("a gap stops the advance") {
        try expectEqual(
            AnchorAdvance.advanced(
                from: makeDate(2026, 8, 9, 10, 0), upTo: limit,
                entries: [entry(10, 0, 10, 20), entry(10, 24, 10, 40)], calendar: testCalendar
            ),
            makeDate(2026, 8, 9, 10, 20)
        )
    }

    test("the advance never passes the limit") {
        try expectEqual(
            AnchorAdvance.advanced(
                from: makeDate(2026, 8, 9, 11, 40), upTo: limit,
                entries: [entry(11, 40, 12, 20)], calendar: testCalendar
            ),
            makeDate(2026, 8, 9, 12, 0)
        )
    }

    test("anchor at the limit stays put") {
        try expectEqual(
            AnchorAdvance.advanced(
                from: limit, upTo: limit,
                entries: [entry(11, 0, 12, 0)], calendar: testCalendar
            ),
            limit
        )
    }
}

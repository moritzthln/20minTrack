import Foundation
import TwentyCore

private func interval(_ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int) -> DateInterval {
    DateInterval(start: makeDate(2026, 8, 9, h1, m1), end: makeDate(2026, 8, 9, h2, m2))
}

func runGapFillTests() {
    test("no blocked intervals leaves the whole range") {
        try expectEqual(
            GapFill.gaps(in: interval(10, 0, 11, 0), blocked: []),
            [interval(10, 0, 11, 0)]
        )
    }

    test("a fully covering block leaves nothing") {
        try expectEqual(
            GapFill.gaps(in: interval(10, 0, 11, 0), blocked: [interval(9, 0, 12, 0)]),
            []
        )
    }

    test("a middle block splits the range") {
        try expectEqual(
            GapFill.gaps(in: interval(10, 0, 11, 0), blocked: [interval(10, 20, 10, 40)]),
            [interval(10, 0, 10, 20), interval(10, 40, 11, 0)]
        )
    }

    test("unsorted and touching blocks merge correctly") {
        try expectEqual(
            GapFill.gaps(
                in: interval(9, 0, 12, 0),
                blocked: [interval(10, 20, 10, 40), interval(9, 40, 10, 20)]
            ),
            [interval(9, 0, 9, 40), interval(10, 40, 12, 0)]
        )
    }

    test("blocks outside the range are ignored") {
        try expectEqual(
            GapFill.gaps(in: interval(10, 0, 11, 0), blocked: [interval(8, 0, 9, 0), interval(11, 0, 12, 0)]),
            [interval(10, 0, 11, 0)]
        )
    }
}

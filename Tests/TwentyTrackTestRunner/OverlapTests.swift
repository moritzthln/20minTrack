import Foundation
import TwentyCore

private func interval(_ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int) -> DateInterval {
    DateInterval(start: makeDate(2026, 8, 9, h1, m1), end: makeDate(2026, 8, 9, h2, m2))
}

func runOverlapTests() {
    test("overlap clips to the range and sums pieces") {
        let seconds = Overlap.seconds(
            of: [interval(9, 50, 10, 5), interval(10, 10, 10, 15)],
            with: interval(10, 0, 10, 20)
        )
        try expectEqual(seconds, 10 * 60, accuracy: 0.5, "5 + 5 min inside")
    }

    test("overlapping intervals count once") {
        let seconds = Overlap.seconds(
            of: [interval(10, 0, 10, 10), interval(10, 5, 10, 15)],
            with: interval(10, 0, 10, 20)
        )
        try expectEqual(seconds, 15 * 60, accuracy: 0.5)
    }

    test("no touching intervals means zero") {
        try expectEqual(
            Overlap.seconds(of: [interval(8, 0, 9, 0)], with: interval(10, 0, 10, 20)),
            0, accuracy: 0.001
        )
    }
}

import Foundation
import TwentyCore

func runSlotGridTests() {
    test("floorBoundary keeps an exact boundary") {
        try expectEqual(
            SlotGrid.floorBoundary(makeDate(2026, 8, 9, 10, 0), calendar: testCalendar),
            makeDate(2026, 8, 9, 10, 0)
        )
    }

    test("floorBoundary floors mid-block times") {
        try expectEqual(
            SlotGrid.floorBoundary(makeDate(2026, 8, 9, 10, 7), calendar: testCalendar),
            makeDate(2026, 8, 9, 10, 0)
        )
        try expectEqual(
            SlotGrid.floorBoundary(makeDate(2026, 8, 9, 10, 39, 59), calendar: testCalendar),
            makeDate(2026, 8, 9, 10, 20)
        )
    }

    test("nextBoundary is strictly after an exact boundary") {
        try expectEqual(
            SlotGrid.nextBoundary(after: makeDate(2026, 8, 9, 10, 0), calendar: testCalendar),
            makeDate(2026, 8, 9, 10, 20)
        )
    }

    test("nextBoundary from mid-block hits the next boundary") {
        try expectEqual(
            SlotGrid.nextBoundary(after: makeDate(2026, 8, 9, 10, 1), calendar: testCalendar),
            makeDate(2026, 8, 9, 10, 20)
        )
        try expectEqual(
            SlotGrid.nextBoundary(after: makeDate(2026, 8, 9, 10, 19, 59), calendar: testCalendar),
            makeDate(2026, 8, 9, 10, 20)
        )
        try expectEqual(
            SlotGrid.nextBoundary(after: makeDate(2026, 8, 9, 23, 40), calendar: testCalendar),
            makeDate(2026, 8, 10, 0, 0)
        )
    }

    test("isOnGrid accepts boundaries and rejects everything else") {
        try expect(SlotGrid.isOnGrid(makeDate(2026, 8, 9, 10, 40), calendar: testCalendar), "10:40")
        try expect(!SlotGrid.isOnGrid(makeDate(2026, 8, 9, 10, 40, 30), calendar: testCalendar), "10:40:30")
        try expect(!SlotGrid.isOnGrid(makeDate(2026, 8, 9, 10, 41), calendar: testCalendar), "10:41")
    }

    test("boundaries lists inclusive grid points in range") {
        let unaligned = SlotGrid.boundaries(
            from: makeDate(2026, 8, 9, 10, 5), to: makeDate(2026, 8, 9, 11, 5),
            calendar: testCalendar
        )
        try expectEqual(unaligned, [
            makeDate(2026, 8, 9, 10, 20),
            makeDate(2026, 8, 9, 10, 40),
            makeDate(2026, 8, 9, 11, 0),
        ])
        let aligned = SlotGrid.boundaries(
            from: makeDate(2026, 8, 9, 10, 0), to: makeDate(2026, 8, 9, 11, 0),
            calendar: testCalendar
        )
        try expectEqual(aligned.count, 4, "10:00–11:00 inclusive")
    }

    test("blockCount counts 20-minute blocks") {
        try expectEqual(
            SlotGrid.blockCount(
                start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
                calendar: testCalendar
            ), 1)
        try expectEqual(
            SlotGrid.blockCount(
                start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 11, 40),
                calendar: testCalendar
            ), 5)
        try expectEqual(
            SlotGrid.blockCount(
                start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 0),
                calendar: testCalendar
            ), 0)
    }

    test("blockCount spans the DST spring-forward gap by absolute time") {
        // Europe/Berlin 2026-03-29: 02:00–03:00 does not exist.
        // 01:40 → 03:20 is 40 absolute minutes = 2 blocks.
        try expectEqual(
            SlotGrid.blockCount(
                start: makeDate(2026, 3, 29, 1, 40), end: makeDate(2026, 3, 29, 3, 20),
                calendar: testCalendar
            ), 2)
    }
}

import Foundation
import TwentyCore

private func makeUsageStore() -> AppUsageStore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("20minTrack-usage-tests-\(UUID().uuidString)", isDirectory: true)
    return AppUsageStore(directory: dir, calendar: testCalendar)
}

private func segment(
    id: UUID = UUID(), _ bundleID: String, _ name: String,
    _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int, day: Int = 9
) -> AppUsageSegment {
    AppUsageSegment(
        id: id, bundleID: bundleID, name: name,
        start: makeDate(2026, 8, day, h1, m1), end: makeDate(2026, 8, day, h2, m2)
    )
}

func runAppUsageTests() {
    test("upsert stores and reads back sorted") {
        let store = makeUsageStore()
        store.upsert(segment("com.b", "Beta", 11, 0, 11, 5))
        store.upsert(segment("com.a", "Alpha", 10, 0, 10, 10))
        let segments = store.segments(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(segments.count, 2)
        try expectEqual(segments[0].name, "Alpha")
        try expectEqual(segments[1].name, "Beta")
    }

    test("upsert replaces by id — heartbeat grows the open segment") {
        let store = makeUsageStore()
        let id = UUID()
        store.upsert(segment(id: id, "com.a", "Alpha", 10, 0, 10, 1))
        store.upsert(segment(id: id, "com.a", "Alpha", 10, 0, 10, 4))
        let segments = store.segments(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(segments.count, 1)
        try expectEqual(segments[0].end, makeDate(2026, 8, 9, 10, 4))
    }

    test("midnight-crossing upsert lands in both day files with the same id") {
        let store = makeUsageStore()
        let id = UUID()
        store.upsert(AppUsageSegment(
            id: id, bundleID: "com.a", name: "Alpha",
            start: makeDate(2026, 8, 8, 23, 50), end: makeDate(2026, 8, 9, 0, 10)
        ))
        let day1 = store.segments(onDay: makeDate(2026, 8, 8, 12, 0))
        let day2 = store.segments(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(day1.count, 1)
        try expectEqual(day1[0].end, makeDate(2026, 8, 9, 0, 0))
        try expectEqual(day2.count, 1)
        try expectEqual(day2[0].start, makeDate(2026, 8, 9, 0, 0))
        try expectEqual(day2[0].id, id)
    }

    test("inverted or empty segments are discarded") {
        let store = makeUsageStore()
        store.upsert(segment("com.a", "Alpha", 10, 0, 10, 0))
        try expectEqual(store.segments(onDay: makeDate(2026, 8, 9, 12, 0)).count, 0)
    }

    test("corrupt usage file reads as empty") {
        let store = makeUsageStore()
        store.upsert(segment("com.a", "Alpha", 10, 0, 10, 5))
        let dir = AppUsageStore.self
        _ = dir
        // overwrite the day file with junk via a second store on same dir
        // (directory is private — recreate the path from the known layout)
        // Simpler: fresh store with its own dir and a junk file:
        let junkDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("20minTrack-usage-junk-\(UUID().uuidString)", isDirectory: true)
        let junkStore = AppUsageStore(directory: junkDir, calendar: testCalendar)
        try "kaputt".data(using: .utf8)!.write(
            to: junkDir.appendingPathComponent("2026-08-09.json")
        )
        try expectEqual(junkStore.segments(onDay: makeDate(2026, 8, 9, 12, 0)).count, 0)
    }

    test("totals clips segments to the range and merges per bundle id") {
        let totals = AppUsageMath.totals(
            segments: [
                segment("com.chrome", "Chrome", 10, 0, 10, 30),
                segment("com.chrome", "Chrome", 10, 40, 10, 45),
                segment("com.slack", "Slack", 10, 15, 10, 21),
            ],
            in: DateInterval(start: makeDate(2026, 8, 9, 10, 10), end: makeDate(2026, 8, 9, 10, 44))
        )
        try expectEqual(totals.count, 2)
        try expectEqual(totals[0].bundleID, "com.chrome")
        try expectEqual(totals[0].seconds, 24 * 60, accuracy: 0.5, "20 min clipped + 4 min clipped")
        try expectEqual(totals[1].bundleID, "com.slack")
        try expectEqual(totals[1].seconds, 6 * 60, accuracy: 0.5)
    }

    test("store totals reads both days of a midnight-spanning range") {
        let store = makeUsageStore()
        store.upsert(AppUsageSegment(
            bundleID: "com.a", name: "Alpha",
            start: makeDate(2026, 8, 8, 23, 50), end: makeDate(2026, 8, 9, 0, 10)
        ))
        let totals = store.totals(in: DateInterval(
            start: makeDate(2026, 8, 8, 23, 40), end: makeDate(2026, 8, 9, 0, 20)
        ))
        try expectEqual(totals.count, 1)
        try expectEqual(totals[0].seconds, 20 * 60, accuracy: 0.5)
    }

    test("totals ignores segments outside the range and keeps the latest name") {
        let totals = AppUsageMath.totals(
            segments: [
                segment("com.a", "Alter Name", 9, 0, 9, 30),
                segment("com.a", "Neuer Name", 10, 0, 10, 10),
                segment("com.b", "Woanders", 8, 0, 8, 30),
            ],
            in: DateInterval(start: makeDate(2026, 8, 9, 9, 0), end: makeDate(2026, 8, 9, 11, 0))
        )
        try expectEqual(totals.count, 1, "com.b lies outside")
        try expectEqual(totals[0].name, "Neuer Name")
        try expectEqual(totals[0].seconds, 40 * 60, accuracy: 0.5)
    }
}

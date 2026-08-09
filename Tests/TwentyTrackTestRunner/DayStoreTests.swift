import Foundation
import TwentyCore

private func makeStore() -> (DayStore, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("20minTrack-tests-\(UUID().uuidString)", isDirectory: true)
    return (DayStore(directory: dir, calendar: testCalendar), dir)
}

func runDayStoreTests() {
    test("insert and read back sorted by start") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 11, 0), end: makeDate(2026, 8, 9, 11, 20),
            labelID: "sport", text: "run"
        )
        store.insert(
            start: makeDate(2026, 8, 9, 9, 0), end: makeDate(2026, 8, 9, 10, 0),
            labelID: "focus-mma", text: "deep work"
        )
        let entries = store.entries(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(entries.count, 2)
        try expectEqual(entries[0].labelID, "focus-mma")
        try expectEqual(entries[0].end, makeDate(2026, 8, 9, 10, 0))
        try expectEqual(entries[1].text, "run")
    }

    test("midnight-crossing insert lands in both day files") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 8, 23, 40), end: makeDate(2026, 8, 9, 0, 20),
            labelID: "sleep", text: "geschlafen"
        )
        let day1 = store.entries(onDay: makeDate(2026, 8, 8, 12, 0))
        let day2 = store.entries(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(day1.count, 1)
        try expectEqual(day1[0].start, makeDate(2026, 8, 8, 23, 40))
        try expectEqual(day1[0].end, makeDate(2026, 8, 9, 0, 0))
        try expectEqual(day2.count, 1)
        try expectEqual(day2[0].start, makeDate(2026, 8, 9, 0, 0))
        try expectEqual(day2[0].end, makeDate(2026, 8, 9, 0, 20))
        try expectEqual(day2[0].labelID, "sleep")
        try expectEqual(day2[0].text, "geschlafen")
    }

    test("exact overlap replaces the old entry") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "orga", text: "mails"
        )
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "fun", text: "youtube"
        )
        let entries = store.entries(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(entries.count, 1)
        try expectEqual(entries[0].labelID, "fun")
    }

    test("inserting over the tail left-trims the old entry") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 11, 0),
            labelID: "orga", text: "a"
        )
        store.insert(
            start: makeDate(2026, 8, 9, 10, 40), end: makeDate(2026, 8, 9, 11, 0),
            labelID: "sport", text: "b"
        )
        let entries = store.entries(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(entries.count, 2)
        try expectEqual(entries[0].end, makeDate(2026, 8, 9, 10, 40))
        try expectEqual(entries[0].labelID, "orga")
        try expectEqual(entries[1].start, makeDate(2026, 8, 9, 10, 40))
    }

    test("inserting over the head right-trims the old entry") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 11, 0),
            labelID: "orga", text: "a"
        )
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "sport", text: "b"
        )
        let entries = store.entries(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(entries.count, 2)
        try expectEqual(entries[0].labelID, "sport")
        try expectEqual(entries[1].start, makeDate(2026, 8, 9, 10, 20))
        try expectEqual(entries[1].end, makeDate(2026, 8, 9, 11, 0))
        try expectEqual(entries[1].labelID, "orga")
    }

    test("inserting into the middle splits the old entry keeping label and text") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 9, 0), end: makeDate(2026, 8, 9, 12, 0),
            labelID: "focus-mma", text: "long block"
        )
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "fun", text: "pause"
        )
        let entries = store.entries(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(entries.count, 3)
        try expectEqual(entries[0].end, makeDate(2026, 8, 9, 10, 0))
        try expectEqual(entries[0].labelID, "focus-mma")
        try expectEqual(entries[0].text, "long block")
        try expectEqual(entries[1].labelID, "fun")
        try expectEqual(entries[2].start, makeDate(2026, 8, 9, 10, 20))
        try expectEqual(entries[2].end, makeDate(2026, 8, 9, 12, 0))
        try expectEqual(entries[2].labelID, "focus-mma")
        try expectEqual(entries[2].text, "long block")
    }

    test("a containing insert drops the old entry") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "orga", text: "a"
        )
        store.insert(
            start: makeDate(2026, 8, 9, 9, 40), end: makeDate(2026, 8, 9, 10, 40),
            labelID: "sport", text: "b"
        )
        let entries = store.entries(onDay: makeDate(2026, 8, 9, 12, 0))
        try expectEqual(entries.count, 1)
        try expectEqual(entries[0].labelID, "sport")
    }

    test("remove deletes by id") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "orga", text: "a"
        )
        let day = makeDate(2026, 8, 9, 12, 0)
        let id = store.entries(onDay: day)[0].id
        store.remove(id: id, onDay: day)
        try expectEqual(store.entries(onDay: day).count, 0)
    }

    test("fazit roundtrips and empty clears it") {
        let (store, _) = makeStore()
        let day = makeDate(2026, 8, 9, 12, 0)
        try expectNil(store.fazit(onDay: day))
        store.setFazit("Guter Tag.", onDay: day)
        try expectEqual(store.fazit(onDay: day), "Guter Tag.")
        store.setFazit("   ", onDay: day)
        try expectNil(store.fazit(onDay: day))
    }

    test("fazit survives entry inserts") {
        let (store, _) = makeStore()
        let day = makeDate(2026, 8, 9, 12, 0)
        store.setFazit("Fazit bleibt.", onDay: day)
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "orga", text: "a"
        )
        try expectEqual(store.fazit(onDay: day), "Fazit bleibt.")
    }

    test("corrupt day file reads as empty and accepts inserts") {
        let (store, dir) = makeStore()
        let file = dir.appendingPathComponent("2026-08-09.json")
        try "not json".data(using: .utf8)!.write(to: file)
        let day = makeDate(2026, 8, 9, 12, 0)
        try expectEqual(store.entries(onDay: day).count, 0)
        store.insert(
            start: makeDate(2026, 8, 9, 10, 0), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "orga", text: "a"
        )
        try expectEqual(store.entries(onDay: day).count, 1)
    }

    test("inverted range is discarded") {
        let (store, _) = makeStore()
        store.insert(
            start: makeDate(2026, 8, 9, 10, 20), end: makeDate(2026, 8, 9, 10, 20),
            labelID: "orga", text: "a"
        )
        try expectEqual(store.entries(onDay: makeDate(2026, 8, 9, 12, 0)).count, 0)
    }
}

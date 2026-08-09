import Foundation
import TwentyCore

private func entry(_ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int, _ label: String, _ text: String = "") -> Entry {
    Entry(
        start: makeDate(2026, 8, 9, h1, m1), end: makeDate(2026, 8, 9, h2, m2),
        labelID: label, text: text
    )
}

func runEntryMergeTests() {
    test("touching entries with same label and text collapse") {
        let merged = EntryMerge.merged([
            entry(10, 0, 10, 20, "focus-mma", "creatorguard"),
            entry(10, 20, 10, 40, "focus-mma", "creatorguard"),
            entry(10, 40, 11, 0, "focus-mma", "creatorguard"),
        ])
        try expectEqual(merged.count, 1)
        try expectEqual(merged[0].start, makeDate(2026, 8, 9, 10, 0))
        try expectEqual(merged[0].end, makeDate(2026, 8, 9, 11, 0))
        try expectEqual(merged[0].ids.count, 3)
    }

    test("empty texts merge, different texts do not") {
        let empties = EntryMerge.merged([
            entry(10, 0, 10, 20, "orga"),
            entry(10, 20, 10, 40, "orga"),
        ])
        try expectEqual(empties.count, 1)
        let different = EntryMerge.merged([
            entry(10, 0, 10, 20, "orga", "mails"),
            entry(10, 20, 10, 40, "orga", "calls"),
        ])
        try expectEqual(different.count, 2)
    }

    test("gaps and label changes break the merge") {
        let gap = EntryMerge.merged([
            entry(10, 0, 10, 20, "sport"),
            entry(10, 40, 11, 0, "sport"),
        ])
        try expectEqual(gap.count, 2)
        let labels = EntryMerge.merged([
            entry(10, 0, 10, 20, "sport"),
            entry(10, 20, 10, 40, "fun"),
        ])
        try expectEqual(labels.count, 2)
    }
}

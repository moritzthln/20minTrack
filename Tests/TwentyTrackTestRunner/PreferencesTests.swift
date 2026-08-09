import Foundation
import TwentyCore

/// Fresh suite per test, cleaned up afterwards (no orphaned plists in
/// ~/Library/Preferences).
private func withPreferences(_ body: (Preferences) throws -> Void) rethrows {
    let suite = "20minTrack-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    try body(Preferences(defaults: defaults))
}

func runPreferencesLabelTests() {
    test("never-set labels seed the six defaults") {
        try withPreferences { prefs in
            let labels = prefs.labels
            try expectEqual(labels.map(\.id), [
                "focus-mma", "no-focus", "orga", "sleep", "fun", "sport",
            ])
            try expectEqual(labels.map(\.name), [
                "Fokus Arbeit MMA", "Kein Fokus", "Orga/Other", "Schlafen", "Spaß", "Sport",
            ])
            try expectEqual(labels[0].colorKey, "green")
            try expectEqual(labels[3].colorKey, "indigo")
            try expect(labels.allSatisfy { !$0.archived }, "no default is archived")
        }
    }

    test("addLabel trims, stores, and rejects empty names") {
        try withPreferences { prefs in
            let added = prefs.addLabel(name: "  Lesen  ", colorKey: "purple")
            try expectEqual(added?.name, "Lesen")
            try expectEqual(prefs.labels.count, 7)
            try expectEqual(prefs.labels.last?.colorKey, "purple")
            try expectNil(prefs.addLabel(name: "   ", colorKey: "pink"))
            try expectEqual(prefs.labels.count, 7)
        }
    }

    test("updateLabel renames and recolors by id") {
        try withPreferences { prefs in
            var label = prefs.labels[1]
            label.name = "Ablenkung"
            label.colorKey = "pink"
            prefs.updateLabel(label)
            try expectEqual(prefs.labels[1].name, "Ablenkung")
            try expectEqual(prefs.labels[1].colorKey, "pink")
            try expectEqual(prefs.labels.count, 6)
        }
    }

    test("updateLabel rejects an empty rename") {
        try withPreferences { prefs in
            var label = prefs.labels[0]
            label.name = "   "
            prefs.updateLabel(label)
            try expectEqual(prefs.labels[0].name, "Fokus Arbeit MMA")
        }
    }

    test("archiveLabel hides from active but stays resolvable") {
        try withPreferences { prefs in
            prefs.archiveLabel(id: "fun")
            try expect(prefs.labels.first { $0.id == "fun" }!.archived, "archived flag set")
            try expectEqual(prefs.activeLabels.count, 5)
            try expectEqual(prefs.label(byID: "fun")?.name, "Spaß")
        }
    }
}

func runPreferencesSettingTests() {
    test("checkinAnchor defaults to nil and roundtrips") {
        try withPreferences { prefs in
            try expectNil(prefs.checkinAnchor)
            let anchor = makeDate(2026, 8, 9, 10, 20)
            prefs.checkinAnchor = anchor
            try expectEqual(prefs.checkinAnchor, anchor)
        }
    }

    test("lastLabelID defaults to nil and roundtrips") {
        try withPreferences { prefs in
            try expectNil(prefs.lastLabelID)
            prefs.lastLabelID = "sport"
            try expectEqual(prefs.lastLabelID, "sport")
        }
    }

    test("chimeVolume defaults to 0.5 and clamps") {
        try withPreferences { prefs in
            try expectEqual(prefs.chimeVolume, 0.5, accuracy: 0.001)
            prefs.chimeVolume = 1.5
            try expectEqual(prefs.chimeVolume, 1.0, accuracy: 0.001)
            prefs.chimeVolume = -1
            try expectEqual(prefs.chimeVolume, 0.0, accuracy: 0.001)
        }
    }

    test("toggles have expected defaults and roundtrip") {
        try withPreferences { prefs in
            try expect(prefs.autoOpenPopover, "autoOpenPopover default true")
            try expect(!prefs.trackingPaused, "trackingPaused default false")
            try expect(!prefs.muted, "muted default false")
            try expect(prefs.suppressDuringFocus, "suppressDuringFocus default true")
            prefs.autoOpenPopover = false
            prefs.trackingPaused = true
            prefs.muted = true
            prefs.suppressDuringFocus = false
            try expect(!prefs.autoOpenPopover, "autoOpenPopover set false")
            try expect(prefs.trackingPaused, "trackingPaused set true")
            try expect(prefs.muted, "muted set true")
            try expect(!prefs.suppressDuringFocus, "suppressDuringFocus set false")
        }
    }

    test("focus assertions detect active records and fail open") {
        let active = #"{"data":[{"storeAssertionRecords":[{"assertionDetails":{"assertionDetailsModeIdentifier":"com.apple.donotdisturb.mode.default"}}]}]}"#
        let empty = #"{"data":[{"storeAssertionRecords":[]}]}"#
        let noData = #"{"data":[]}"#
        try expect(FocusAssertions.isActive(json: Data(active.utf8)), "active record")
        try expect(!FocusAssertions.isActive(json: Data(empty.utf8)), "empty records")
        try expect(!FocusAssertions.isActive(json: Data(noData.utf8)), "no data entries")
        try expect(!FocusAssertions.isActive(json: Data("junk".utf8)), "corrupt json")
    }
}

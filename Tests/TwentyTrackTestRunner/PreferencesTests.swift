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
    test("never-set labels seed the shipped defaults in both languages") {
        let german = TrackLabel.defaults(german: true)
        let english = TrackLabel.defaults(german: false)
        let expectedIDs = [
            "focus-mma", "half-focus", "orga", "calls",
            "no-focus", "fun", "sport", "sleep",
        ]
        try expectEqual(german.map(\.id), expectedIDs)
        try expectEqual(english.map(\.id), expectedIDs, "ids are language-independent")
        try expectEqual(german.map(\.name), [
            "Fokus Arbeit", "Halbfokus", "Orga & Alltag", "Calls",
            "Ablenkung", "Erholung", "Sport", "Schlafen",
        ])
        try expectEqual(english.map(\.name), [
            "Focus Work", "Half Focus", "Admin & Everyday", "Calls",
            "Distraction", "Recreation", "Sport", "Sleep",
        ])
        try expectEqual(german[0].colorKey, "green")
        try expect(german.allSatisfy { !$0.archived }, "no default is archived")
        try expect(german.allSatisfy { $0.goalMinutes == nil }, "no default goal")
        try withPreferences { prefs in
            try expectEqual(prefs.labels.map(\.id), expectedIDs, "prefs fall back to defaults")
        }
    }

    test("addLabel trims, stores, and rejects empty names") {
        try withPreferences { prefs in
            let base = prefs.labels.count
            let added = prefs.addLabel(name: "  Lesen  ", colorKey: "purple")
            try expectEqual(added?.name, "Lesen")
            try expectEqual(prefs.labels.count, base + 1)
            try expectEqual(prefs.labels.last?.colorKey, "purple")
            try expectNil(prefs.addLabel(name: "   ", colorKey: "pink"))
            try expectEqual(prefs.labels.count, base + 1)
        }
    }

    test("updateLabel renames and recolors by id") {
        try withPreferences { prefs in
            let base = prefs.labels.count
            var label = prefs.labels[1]
            label.name = "Umbenannt"
            label.colorKey = "pink"
            prefs.updateLabel(label)
            try expectEqual(prefs.labels[1].name, "Umbenannt")
            try expectEqual(prefs.labels[1].colorKey, "pink")
            try expectEqual(prefs.labels.count, base)
        }
    }

    test("updateLabel rejects an empty rename") {
        try withPreferences { prefs in
            let original = prefs.labels[0].name
            var label = prefs.labels[0]
            label.name = "   "
            prefs.updateLabel(label)
            try expectEqual(prefs.labels[0].name, original)
        }
    }

    test("label goals roundtrip and pre-goal data decodes") {
        try withPreferences { prefs in
            var label = prefs.labels[0]
            label.goalMinutes = 270
            prefs.updateLabel(label)
            try expectEqual(prefs.labels[0].goalMinutes, 270)
        }
        let old = #"[{"id":"x","name":"X","colorKey":"green","archived":false}]"#
        let decoded = try JSONDecoder().decode([TrackLabel].self, from: Data(old.utf8))
        try expectNil(decoded[0].goalMinutes)
    }

    test("archiveLabel hides from active but stays resolvable") {
        try withPreferences { prefs in
            let base = prefs.activeLabels.count
            prefs.archiveLabel(id: "fun")
            try expect(prefs.labels.first { $0.id == "fun" }!.archived, "archived flag set")
            try expectEqual(prefs.activeLabels.count, base - 1)
            try expectEqual(prefs.label(byID: "fun")?.name, "Erholung")
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
            try expect(prefs.suppressDuringFocus, "suppressDuringFocus default true")
            prefs.autoOpenPopover = false
            prefs.trackingPaused = true
            prefs.suppressDuringFocus = false
            try expect(!prefs.autoOpenPopover, "autoOpenPopover set false")
            try expect(prefs.trackingPaused, "trackingPaused set true")
            try expect(!prefs.suppressDuringFocus, "suppressDuringFocus set false")
        }
    }

    test("mute expires on its own") {
        try withPreferences { prefs in
            let now = makeDate(2026, 8, 19, 12, 0)
            try expect(!prefs.isMuted(now: now), "default not muted")
            prefs.mutedUntil = makeDate(2026, 8, 19, 13, 0)
            try expect(prefs.isMuted(now: now), "muted before expiry")
            try expect(!prefs.isMuted(now: makeDate(2026, 8, 19, 13, 0)), "expiry is exclusive")
            prefs.mutedUntil = nil
            try expect(!prefs.isMuted(now: now), "unmuted")
        }
    }

    test("absences default empty, roundtrip sorted, swap inverted bounds") {
        try withPreferences { prefs in
            try expect(prefs.absences.isEmpty, "default empty")
            prefs.addAbsence(
                name: "  Urlaub  ",
                startDay: makeDate(2026, 9, 10, 0, 0), endDay: makeDate(2026, 9, 12, 0, 0)
            )
            let swapped = prefs.addAbsence(
                name: "", startDay: makeDate(2026, 9, 5, 0, 0), endDay: makeDate(2026, 9, 1, 0, 0)
            )
            try expectEqual(prefs.absences.count, 2)
            try expectEqual(prefs.absences[0].name, "Abwesend", "sorted by start, fallback name")
            try expectEqual(prefs.absences[0].startDay, makeDate(2026, 9, 1, 0, 0), "bounds swapped")
            try expectEqual(prefs.absences[1].name, "Urlaub")
            prefs.removeAbsence(id: swapped.id)
            try expectEqual(prefs.absences.count, 1)
        }
    }

    test("fazit prompt defaults to 21:30 enabled and clamps") {
        try withPreferences { prefs in
            try expect(prefs.fazitPromptEnabled, "enabled by default")
            try expectEqual(prefs.fazitPromptMinute, 1290)
            prefs.fazitPromptMinute = 5000
            try expectEqual(prefs.fazitPromptMinute, 1439)
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

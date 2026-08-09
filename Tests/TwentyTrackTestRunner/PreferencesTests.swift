import Foundation
import TwentyCore

private func makePreferences() -> Preferences {
    let suite = "20minTrack-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return Preferences(defaults: defaults)
}

func runPreferencesTests() {
    test("never-set labels seed the six defaults") {
        let prefs = makePreferences()
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

    test("addLabel trims, stores, and rejects empty names") {
        let prefs = makePreferences()
        let added = prefs.addLabel(name: "  Lesen  ", colorKey: "purple")
        try expectEqual(added?.name, "Lesen")
        try expectEqual(prefs.labels.count, 7)
        try expectEqual(prefs.labels.last?.colorKey, "purple")
        try expectNil(prefs.addLabel(name: "   ", colorKey: "pink"))
        try expectEqual(prefs.labels.count, 7)
    }

    test("updateLabel renames and recolors by id") {
        let prefs = makePreferences()
        var label = prefs.labels[1]
        label.name = "Ablenkung"
        label.colorKey = "pink"
        prefs.updateLabel(label)
        try expectEqual(prefs.labels[1].name, "Ablenkung")
        try expectEqual(prefs.labels[1].colorKey, "pink")
        try expectEqual(prefs.labels.count, 6)
    }

    test("archiveLabel hides from active but stays resolvable") {
        let prefs = makePreferences()
        prefs.archiveLabel(id: "fun")
        try expect(prefs.labels.first { $0.id == "fun" }!.archived, "archived flag set")
        try expectEqual(prefs.activeLabels.count, 5)
        try expectEqual(prefs.label(byID: "fun")?.name, "Spaß")
    }

    test("checkinAnchor defaults to nil and roundtrips") {
        let prefs = makePreferences()
        try expectNil(prefs.checkinAnchor)
        let anchor = makeDate(2026, 8, 9, 10, 20)
        prefs.checkinAnchor = anchor
        try expectEqual(prefs.checkinAnchor, anchor)
    }

    test("chimeVolume defaults to 0.5 and clamps") {
        let prefs = makePreferences()
        try expectEqual(prefs.chimeVolume, 0.5, accuracy: 0.001)
        prefs.chimeVolume = 1.5
        try expectEqual(prefs.chimeVolume, 1.0, accuracy: 0.001)
        prefs.chimeVolume = -1
        try expectEqual(prefs.chimeVolume, 0.0, accuracy: 0.001)
    }

    test("toggles have expected defaults and roundtrip") {
        let prefs = makePreferences()
        try expect(prefs.autoOpenPopover, "autoOpenPopover default true")
        try expect(!prefs.trackingPaused, "trackingPaused default false")
        prefs.autoOpenPopover = false
        prefs.trackingPaused = true
        try expect(!prefs.autoOpenPopover, "autoOpenPopover set false")
        try expect(prefs.trackingPaused, "trackingPaused set true")
    }
}

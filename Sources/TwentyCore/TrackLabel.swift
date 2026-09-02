import Foundation

/// A user-defined activity label. Archived labels disappear from pickers
/// but stay resolvable so historic entries keep their name and color.
/// (Named TrackLabel — `Label` clashes with SwiftUI.)
public struct TrackLabel: Codable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var colorKey: String
    public var archived: Bool
    /// Daily minimum goal in minutes (nil = no goal). Stored data without
    /// the field decodes as nil — pre-goal labels stay valid.
    public var goalMinutes: Int?

    public init(
        id: String, name: String, colorKey: String,
        archived: Bool = false, goalMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.colorKey = colorKey
        self.archived = archived
        self.goalMinutes = goalMinutes
    }

    /// The labels the app ships with (stable slug ids — entries reference
    /// these forever, names and colors stay editable). Order = the ⌘1–⌘9/⌘0
    /// shortcut order: the work-quality trio first (green → yellow → red
    /// is the ratio that matters), then the rest of the day. Names follow
    /// the system language on first launch; goals stay unset.
    /// UserDefaults key of the app's manual language override — checked
    /// first so seeded names match the effective UI language, not just
    /// the system one.
    public static let languageOverrideDefaultsKey = "languageOverride"

    public static func effectiveGerman() -> Bool {
        let code = UserDefaults.standard.string(forKey: languageOverrideDefaultsKey)
            ?? Locale.preferredLanguages.first
            ?? "en"
        return code.lowercased().hasPrefix("de")
    }

    public static func defaults(german: Bool = effectiveGerman()) -> [TrackLabel] {
        func name(_ de: String, _ en: String) -> String { german ? de : en }
        return [
            TrackLabel(id: "focus-mma", name: name("Fokus Arbeit", "Focus Work"), colorKey: "green"),
            TrackLabel(id: "half-focus", name: name("Halbfokus", "Half Focus"), colorKey: "yellow"),
            TrackLabel(id: "orga", name: name("Orga & Alltag", "Admin & Everyday"), colorKey: "blue"),
            TrackLabel(id: "calls", name: name("Calls", "Calls"), colorKey: "mint"),
            TrackLabel(id: "no-focus", name: name("Ablenkung", "Distraction"), colorKey: "red"),
            TrackLabel(id: "fun", name: name("Erholung", "Recreation"), colorKey: "orange"),
            TrackLabel(id: "sport", name: name("Sport", "Sport"), colorKey: "teal"),
            TrackLabel(id: "sleep", name: name("Schlafen", "Sleep"), colorKey: "indigo"),
        ]
    }

    /// Renames every label that still carries a stock default name (in
    /// either language) to the target language's default; custom names
    /// and all ids stay untouched. Used when the UI language switches.
    public static func relocalized(_ labels: [TrackLabel], german: Bool) -> [TrackLabel] {
        let sourceNames = [true, false].map { defaults(german: $0) }
        let targetByID = Dictionary(
            defaults(german: german).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        return labels.map { label in
            let isStock = sourceNames.contains { variant in
                variant.contains { $0.id == label.id && $0.name == label.name }
            }
            guard isStock, let target = targetByID[label.id] else { return label }
            var updated = label
            updated.name = target
            return updated
        }
    }

    /// Palette keys the settings color picker offers.
    public static let paletteKeys = [
        "green", "red", "blue", "indigo", "orange", "teal",
        "pink", "purple", "yellow", "mint", "brown", "gray",
    ]
}

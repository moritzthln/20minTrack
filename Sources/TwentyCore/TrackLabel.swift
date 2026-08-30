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
    /// these forever, names and colors stay editable). Order = the ⌘1–⌘9
    /// shortcut order: the work-quality trio first (green → yellow → red
    /// is the ratio that matters), then the rest of the day. Names follow
    /// the system language on first launch; goals stay unset.
    public static func defaults(
        german: Bool = Locale.preferredLanguages.first?.lowercased().hasPrefix("de") ?? false
    ) -> [TrackLabel] {
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

    /// Palette keys the settings color picker offers.
    public static let paletteKeys = [
        "green", "red", "blue", "indigo", "orange", "teal",
        "pink", "purple", "yellow", "mint", "brown", "gray",
    ]
}

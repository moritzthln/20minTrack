import Foundation

/// A user-defined activity label. Archived labels disappear from pickers
/// but stay resolvable so historic entries keep their name and color.
/// (Named TrackLabel — `Label` clashes with SwiftUI.)
public struct TrackLabel: Codable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var colorKey: String
    public var archived: Bool

    public init(id: String, name: String, colorKey: String, archived: Bool = false) {
        self.id = id
        self.name = name
        self.colorKey = colorKey
        self.archived = archived
    }

    /// The six labels the app ships with (stable slug ids — entries
    /// reference these forever, names and colors stay editable).
    public static func defaults() -> [TrackLabel] {
        [
            TrackLabel(id: "focus-mma", name: "Fokus Arbeit MMA", colorKey: "green"),
            TrackLabel(id: "no-focus", name: "Kein Fokus", colorKey: "red"),
            TrackLabel(id: "orga", name: "Orga/Other", colorKey: "blue"),
            TrackLabel(id: "sleep", name: "Schlafen", colorKey: "indigo"),
            TrackLabel(id: "fun", name: "Spaß", colorKey: "orange"),
            TrackLabel(id: "sport", name: "Sport", colorKey: "teal"),
        ]
    }

    /// Palette keys the settings color picker offers.
    public static let paletteKeys = [
        "green", "red", "blue", "indigo", "orange", "teal",
        "pink", "purple", "yellow", "mint", "brown", "gray",
    ]
}

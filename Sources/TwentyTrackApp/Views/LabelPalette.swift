import SwiftUI
import TwentyCore

/// Maps stored color keys to SwiftUI colors. Unknown keys (and unknown
/// label ids) render gray.
enum LabelPalette {
    static func color(for key: String) -> Color {
        switch key {
        case "green": return .green
        case "red": return .red
        case "blue": return .blue
        case "indigo": return .indigo
        case "orange": return .orange
        case "teal": return .teal
        case "pink": return .pink
        case "purple": return .purple
        case "yellow": return .yellow
        case "mint": return .mint
        case "brown": return .brown
        default: return .gray
        }
    }

    static let untracked = Color.gray.opacity(0.22)

    static func color(labelID: String, labelsByID: [String: TrackLabel]) -> Color {
        guard let label = labelsByID[labelID] else { return .gray }
        return color(for: label.colorKey)
    }
}

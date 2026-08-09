import Foundation

/// One logged span: what happened between two grid boundaries. Entries are
/// half-open `[start, end)`, never overlap within a day, and never cross
/// midnight (DayStore splits on insert).
public struct Entry: Codable, Equatable, Identifiable {
    public let id: UUID
    public let start: Date
    public let end: Date
    public let labelID: String
    public let text: String

    public init(id: UUID = UUID(), start: Date, end: Date, labelID: String, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.labelID = labelID
        self.text = text
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// On-disk shape of one day: `days/YYYY-MM-DD.json`.
struct DayFile: Codable {
    var entries: [Entry]
    var fazit: String?

    static let empty = DayFile(entries: [], fazit: nil)
}

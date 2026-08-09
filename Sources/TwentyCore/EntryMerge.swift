import Foundation

/// One display row of the statistics entry list: adjacent entries with
/// equal label and equal text collapsed into a single span. Display-time
/// only — stored entries never change; `ids` carries the underlying
/// entries so edits and deletes can address all of them.
public struct MergedEntry: Equatable, Identifiable {
    public let ids: [UUID]
    public let start: Date
    public let end: Date
    public let labelID: String
    public let text: String

    public var id: UUID { ids[0] }
}

public enum EntryMerge {
    /// Collapses touching neighbors (`end == next.start`) with the same
    /// label and the same text (case-insensitive — "youtube"/"Youtube"
    /// are one activity; the first spelling wins). A gap, a different
    /// label, or a different text starts a new row.
    public static func merged(_ entries: [Entry]) -> [MergedEntry] {
        var result: [MergedEntry] = []
        for entry in entries.sorted(by: { $0.start < $1.start }) {
            if let last = result.last,
               last.end == entry.start,
               last.labelID == entry.labelID,
               last.text.lowercased() == entry.text.lowercased() {
                result[result.count - 1] = MergedEntry(
                    ids: last.ids + [entry.id],
                    start: last.start, end: entry.end,
                    labelID: last.labelID, text: last.text
                )
            } else {
                result.append(MergedEntry(
                    ids: [entry.id],
                    start: entry.start, end: entry.end,
                    labelID: entry.labelID, text: entry.text
                ))
            }
        }
        return result
    }
}

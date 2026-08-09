import Foundation

/// Interval subtraction: the check-in only fills time that no manual entry
/// already covers, so a strip edit inside the pending window survives the
/// next "Speichern".
public enum GapFill {
    /// The parts of `range` not covered by any `blocked` interval,
    /// ascending. Blocked intervals may be unsorted and overlapping.
    public static func gaps(in range: DateInterval, blocked: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        var cursor = range.start
        for block in blocked.sorted(by: { $0.start < $1.start }) {
            guard block.end > range.start, block.start < range.end else { continue }
            if block.start > cursor {
                result.append(DateInterval(start: cursor, end: block.start))
            }
            cursor = max(cursor, block.end)
            if cursor >= range.end { return result }
        }
        if cursor < range.end {
            result.append(DateInterval(start: cursor, end: range.end))
        }
        return result
    }
}

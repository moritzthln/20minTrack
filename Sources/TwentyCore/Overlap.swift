import Foundation

/// Total overlap of a set of intervals with one range — the math behind
/// the Timer-focus label suggestion (intervals may overlap each other;
/// overlapping parts count once via a merge sweep).
public enum Overlap {
    public static func seconds(of intervals: [DateInterval], with range: DateInterval) -> TimeInterval {
        var total: TimeInterval = 0
        var cursor = range.start
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            let start = max(interval.start, max(cursor, range.start))
            let end = min(interval.end, range.end)
            guard end > start else { continue }
            total += end.timeIntervalSince(start)
            cursor = end
            if cursor >= range.end { break }
        }
        return total
    }
}

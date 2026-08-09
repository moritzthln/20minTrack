import Foundation

/// Wall-clock 20-minute grid (:00 / :20 / :40). All math goes through
/// Calendar so DST transitions never produce phantom or missing blocks:
/// boundaries are wall-clock aligned, distances are absolute time.
public enum SlotGrid {
    public static let blockMinutes = 20
    public static let blocksPerDay = 72
    private static let maxIterations = 5000

    public static func floorBoundary(_ date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        comps.minute = ((comps.minute ?? 0) / blockMinutes) * blockMinutes
        comps.second = 0
        comps.nanosecond = 0
        guard let floored = calendar.date(from: comps), floored <= date else {
            return date
        }
        return floored
    }

    /// The first grid boundary strictly after `date`. The loop guards the
    /// DST fall-back hour, where flooring repeated wall times can land more
    /// than one block behind `date`.
    public static func nextBoundary(after date: Date, calendar: Calendar) -> Date {
        var boundary = floorBoundary(date, calendar: calendar)
        var iterations = 0
        while boundary <= date, iterations < maxIterations {
            guard let next = calendar.date(
                byAdding: .minute, value: blockMinutes, to: boundary
            ) else { break }
            boundary = next
            iterations += 1
        }
        return boundary
    }

    public static func isOnGrid(_ date: Date, calendar: Calendar) -> Bool {
        let comps = calendar.dateComponents([.minute, .second, .nanosecond], from: date)
        return (comps.minute ?? 0) % blockMinutes == 0
            && (comps.second ?? 0) == 0
            && (comps.nanosecond ?? 0) < 1_000_000
    }

    /// All grid boundaries `b` with `from <= b <= to`, ascending.
    public static func boundaries(from: Date, to: Date, calendar: Calendar) -> [Date] {
        guard from <= to else { return [] }
        var result: [Date] = []
        var boundary = isOnGrid(from, calendar: calendar)
            ? from
            : nextBoundary(after: from, calendar: calendar)
        while boundary <= to, result.count < maxIterations {
            result.append(boundary)
            boundary = nextBoundary(after: boundary, calendar: calendar)
        }
        return result
    }

    /// Number of whole 20-minute blocks between two grid-aligned dates.
    public static func blockCount(start: Date, end: Date, calendar: Calendar) -> Int {
        guard end > start else { return 0 }
        var count = 0
        var boundary = nextBoundary(after: start, calendar: calendar)
        while boundary <= end, count < maxIterations {
            count += 1
            boundary = nextBoundary(after: boundary, calendar: calendar)
        }
        return count
    }
}

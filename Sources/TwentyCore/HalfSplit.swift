import Foundation

/// Splitting a span between two labels: every 20-minute block is halved,
/// so a block becomes 10 min for the first and 10 min for the second
/// label. Partial blocks (a span that does not start or end on the grid)
/// are halved at their own midpoint.
public enum HalfSplit {
    private static let maxIterations = 500

    public static func halves(
        of interval: DateInterval, calendar: Calendar
    ) -> [(first: DateInterval, second: DateInterval)] {
        guard interval.duration > 0 else { return [] }
        var result: [(first: DateInterval, second: DateInterval)] = []
        var cursor = interval.start
        var iterations = 0
        while cursor < interval.end, iterations < maxIterations {
            iterations += 1
            let blockEnd = min(
                SlotGrid.nextBoundary(after: cursor, calendar: calendar), interval.end
            )
            let middle = cursor.addingTimeInterval(blockEnd.timeIntervalSince(cursor) / 2)
            guard middle > cursor, blockEnd > middle else {
                cursor = blockEnd
                continue
            }
            result.append((
                DateInterval(start: cursor, end: middle),
                DateInterval(start: middle, end: blockEnd)
            ))
            cursor = blockEnd
        }
        return result
    }
}

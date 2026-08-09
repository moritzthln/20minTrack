import Foundation

/// Backfilled time counts as settled: starting at the anchor, advance
/// block by block while each whole block is covered by entries. Applied on
/// every reload, so manually filled blocks never re-prompt.
public enum AnchorAdvance {
    private static let maxIterations = 5000

    public static func advanced(
        from anchor: Date, upTo limit: Date, entries: [Entry], calendar: Calendar
    ) -> Date {
        let blocked = entries.map { DateInterval(start: $0.start, end: $0.end) }
        var cursor = anchor
        var iterations = 0
        while cursor < limit, iterations < maxIterations {
            let blockEnd = SlotGrid.nextBoundary(after: cursor, calendar: calendar)
            guard blockEnd <= limit else { break }
            let block = DateInterval(start: cursor, end: blockEnd)
            guard GapFill.gaps(in: block, blocked: blocked).isEmpty else { break }
            cursor = blockEnd
            iterations += 1
        }
        return cursor
    }
}

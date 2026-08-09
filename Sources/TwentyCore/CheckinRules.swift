import Foundation

/// Decides what span the next check-in covers. The anchor marks the end of
/// settled time (logged or deliberately skipped); everything between the
/// anchor and the last completed grid boundary is pending. The lookback is
/// capped at the start of yesterday so a long-offline machine never
/// produces a monster block.
public enum CheckinRules {
    public static func pendingRange(
        anchor: Date?, now: Date, calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard let anchor else { return nil }
        let end = SlotGrid.floorBoundary(now, calendar: calendar)
        let todayStart = calendar.startOfDay(for: now)
        guard let lookbackFloor = calendar.date(
            byAdding: .day, value: -1, to: todayStart
        ) else { return nil }
        let start = max(anchor, lookbackFloor)
        guard start < end else { return nil }
        return (start, end)
    }
}

import Foundation

/// How untracked time counts once a day can no longer be backfilled
/// through the check-in (its lookback reaches back to yesterday):
/// on settled days — older than yesterday — leftover gaps were a
/// deliberate decision not to track, so they count as distraction.
/// Today and yesterday keep showing "Nicht erfasst".
///
/// A day without a single entry is never attributed: those are days the
/// app did not run at all (before install, Mac off, holiday) and turning
/// them into 24 h of distraction would drown every statistic.
public enum DayAttribution {
    public static func isSettled(day: Date, now: Date, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: now)
        guard let yesterdayStart = calendar.date(
            byAdding: .day, value: -1, to: todayStart
        ) else { return false }
        return dayStart < yesterdayStart
    }

    /// Per-label totals for one day plus the untracked seconds that are
    /// still shown as "Nicht erfasst".
    public static func totals(
        day: Date, entries: [Entry], now: Date, calendar: Calendar,
        distractionLabelID: String, isAbsent: Bool = false
    ) -> (totals: [String: TimeInterval], untracked: TimeInterval) {
        var totals = StatsMath.totals(entries)
        let untracked = StatsMath.untrackedSeconds(
            day: day, reference: now, entries: entries, calendar: calendar
        )
        guard !isAbsent,
              !entries.isEmpty,
              untracked > 0,
              isSettled(day: day, now: now, calendar: calendar) else {
            return (totals, untracked)
        }
        totals[distractionLabelID, default: 0] += untracked
        return (totals, 0)
    }
}

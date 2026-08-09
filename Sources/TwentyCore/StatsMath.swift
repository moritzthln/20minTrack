import Foundation

/// Pure aggregation over entries — the numbers behind the statistics.
public enum StatsMath {
    public static func totals(_ entries: [Entry]) -> [String: TimeInterval] {
        entries.reduce(into: [:]) { result, entry in
            result[entry.labelID, default: 0] += entry.duration
        }
    }

    public static func trackedSeconds(_ entries: [Entry]) -> TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }

    /// Elapsed-but-unlogged time of a day. For past days the whole day
    /// counts as elapsed; for the reference day only the time up to
    /// `reference`. Never negative.
    public static func untrackedSeconds(
        day: Date, reference: Date, entries: [Entry], calendar: Calendar
    ) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        let elapsedEnd = min(dayEnd, max(reference, dayStart))
        let elapsed = elapsedEnd.timeIntervalSince(dayStart)
        return max(0, elapsed - trackedSeconds(entries))
    }

    /// German-style whole-percent share ("39 %"). Halves round up; > 0 but
    /// < 0.5 % renders "<1 %"; zero seconds or zero basis → nil.
    public static func percentLabel(seconds: TimeInterval, total: TimeInterval) -> String? {
        guard total > 0, seconds > 0 else { return nil }
        let percent = Int((seconds / total * 100).rounded())
        return percent == 0 ? "<1 %" : "\(percent) %"
    }

    /// The seven local days (start-of-day dates) of the ISO week —
    /// Monday first — containing `date`. Locale-independent.
    public static func weekDays(containing date: Date, calendar: Calendar) -> [Date] {
        let dayStart = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: dayStart) // 1 = Sunday
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(
            byAdding: .day, value: -daysSinceMonday, to: dayStart
        ) else { return [dayStart] }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: monday)
        }
    }
}

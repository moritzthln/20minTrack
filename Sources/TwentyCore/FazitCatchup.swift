import Foundation

/// Morning catch-up for a missed evening Fazit: if yesterday ended
/// without a review, one extra prompt fires the next day at 09:30.
/// The window closes when the regular evening prompt takes over, so
/// the two reminders never stack. Days without entries and absent
/// days (either yesterday or today) never prompt.
public enum FazitCatchup {
    /// 09:30 — minute of day the catch-up becomes due.
    public static let startMinute = 570

    /// The day whose Fazit should be caught up right now, or nil.
    /// Firing once per day is the caller's job (same in-memory marker
    /// pattern as the evening prompt).
    public static func dueDay(
        now: Date, calendar: Calendar,
        yesterdayHasFazit: Bool,
        yesterdayHasEntries: Bool,
        eveningPromptMinute: Int,
        absences: [Absence]
    ) -> Date? {
        let minute = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)
        guard minute >= startMinute, minute < eveningPromptMinute else { return nil }
        guard !yesterdayHasFazit, yesterdayHasEntries else { return nil }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return nil
        }
        guard !AbsenceRules.isAbsent(day: yesterday, in: absences, calendar: calendar),
              !AbsenceRules.isAbsent(day: today, in: absences, calendar: calendar)
        else { return nil }
        return yesterday
    }
}

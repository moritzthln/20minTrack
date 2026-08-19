import Foundation

/// A planned away period (vacation, trip): whole days, inclusive bounds.
/// Absence is a property of the day, not an activity — absent days never
/// prompt, never count their gaps as distraction, and the anchor skips
/// over them on return.
public struct Absence: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var startDay: Date
    public var endDay: Date

    public init(id: UUID = UUID(), name: String, startDay: Date, endDay: Date) {
        self.id = id
        self.name = name
        self.startDay = startDay
        self.endDay = endDay
    }
}

public enum AbsenceRules {
    /// The absence covering the given day, if any (bounds inclusive,
    /// compared per local day).
    public static func absence(
        containing day: Date, in absences: [Absence], calendar: Calendar
    ) -> Absence? {
        let dayStart = calendar.startOfDay(for: day)
        return absences.first { absence in
            dayStart >= calendar.startOfDay(for: absence.startDay)
                && dayStart <= calendar.startOfDay(for: absence.endDay)
        }
    }

    public static func isAbsent(
        day: Date, in absences: [Absence], calendar: Calendar
    ) -> Bool {
        absence(containing: day, in: absences, calendar: calendar) != nil
    }

    /// Moves an anchor sitting inside an absence to the first midnight
    /// after it (chained absences are walked through) — the return
    /// check-in never asks about away days.
    public static func normalizedAnchor(
        _ anchor: Date, absences: [Absence], calendar: Calendar
    ) -> Date {
        var current = anchor
        var iterations = 0
        while iterations < 100,
              let absence = absence(containing: current, in: absences, calendar: calendar) {
            let endStart = calendar.startOfDay(for: absence.endDay)
            guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: endStart) else {
                break
            }
            current = nextMidnight
            iterations += 1
        }
        return max(anchor, current)
    }
}

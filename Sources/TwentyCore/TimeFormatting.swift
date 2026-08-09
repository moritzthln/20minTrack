import Foundation

public enum TimeFormatting {
    /// Duration wording for statistics: "45 min", "1 h 25 min", "2 h".
    public static func wording(seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours) h \(minutes) min" }
        if hours > 0 { return "\(hours) h" }
        return "\(minutes) min"
    }

    /// 24-hour wall time ("09:05") in the calendar's time zone.
    public static func clock(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}

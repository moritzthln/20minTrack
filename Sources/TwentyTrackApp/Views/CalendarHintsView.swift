import SwiftUI
import TwentyCore

/// "In your calendar": timed events overlapping the span — a memory aid
/// next to the app usage list. Never creates or changes an entry.
struct CalendarHintsView: View {
    let events: [CalendarEventInfo]
    let calendar: Calendar

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc("Im Kalender", "In your calendar"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(event.title.isEmpty ? loc("(ohne Titel)", "(untitled)") : event.title)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        Text("\(TimeFormatting.clock(event.start, calendar: calendar))–\(TimeFormatting.clock(event.end, calendar: calendar))")
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
        }
    }
}

extension CalendarHints {
    /// The hints the app shows for `range`: empty unless enabled in
    /// Settings and calendar access was granted.
    static func current(in range: DateInterval, preferences: Preferences) -> [CalendarEventInfo] {
        guard preferences.calendarHintsEnabled else { return [] }
        return events(
            CalendarReader.shared.events(in: range),
            overlapping: range, calendarIDs: Set(preferences.calendarIDs)
        )
    }
}

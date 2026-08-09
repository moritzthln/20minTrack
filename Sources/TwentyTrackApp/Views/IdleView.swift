import SwiftUI
import TwentyCore

/// Shown when nothing is pending: everything is logged, next prompt ahead.
struct IdleView: View {
    let calendar: Calendar
    let paused: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: paused ? "pause.circle" : "checkmark.circle")
                        .foregroundStyle(paused ? Color.orange : Color.green)
                    Text(paused ? "Tracking pausiert" : "Alles erfasst")
                        .font(.headline)
                }
                if !paused {
                    nextLine(now: context.date)
                }
            }
        }
    }

    private func nextLine(now: Date) -> some View {
        let next = SlotGrid.nextBoundary(after: now, calendar: calendar)
        let minutes = max(1, Int(ceil(next.timeIntervalSince(now) / 60)))
        return Text(
            "Nächster Check-in um \(TimeFormatting.clock(next, calendar: calendar)) · in \(minutes) min"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

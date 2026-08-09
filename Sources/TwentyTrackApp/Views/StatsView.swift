import SwiftUI
import TwentyCore

/// Root of the Statistik window: Tag | Woche. Plain @State — a fresh
/// hosting view per window open resets to Tag and reloads (Timer pattern).
struct StatsView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar

    private enum Tab: String, CaseIterable {
        case day = "Tag"
        case week = "Woche"
    }

    @State private var tab: Tab = .day

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 220)
            switch tab {
            case .day:
                StatsDayView(dayStore: dayStore, preferences: preferences, calendar: calendar)
            case .week:
                StatsWeekView(dayStore: dayStore, preferences: preferences, calendar: calendar)
            }
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 500)
    }
}

/// Shared per-label duration list ("Fokus Arbeit MMA — 3 h 20 min · 42 %"),
/// sorted by duration, plus an untracked line.
struct LabelTotalsList: View {
    let totals: [String: TimeInterval]
    let untrackedSeconds: TimeInterval
    let labelsByID: [String: TrackLabel]

    private var rows: [(label: TrackLabel?, id: String, seconds: TimeInterval)] {
        totals
            .map { (labelsByID[$0.key], $0.key, $0.value) }
            .sorted { $0.2 > $1.2 }
    }

    private var trackedTotal: TimeInterval {
        totals.values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.id) { row in
                HStack(spacing: 8) {
                    Circle()
                        .fill(row.label.map { LabelPalette.color(for: $0.colorKey) } ?? .gray)
                        .frame(width: 9, height: 9)
                    Text(row.label?.name ?? "Unbekannt")
                        .lineLimit(1)
                    Spacer()
                    durationText(row.seconds, share: true)
                }
                .font(.callout)
            }
            if untrackedSeconds > 0 {
                HStack(spacing: 8) {
                    Circle().fill(LabelPalette.untracked).frame(width: 9, height: 9)
                    Text("Nicht erfasst").foregroundStyle(.secondary)
                    Spacer()
                    durationText(untrackedSeconds, share: false)
                }
                .font(.callout)
            }
            if rows.isEmpty && untrackedSeconds <= 0 {
                Text("Keine Einträge.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func durationText(_ seconds: TimeInterval, share: Bool) -> some View {
        var text = TimeFormatting.wording(seconds: seconds)
        if share, let percent = StatsMath.percentLabel(seconds: seconds, total: trackedTotal) {
            text += " · \(percent)"
        }
        return Text(text)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

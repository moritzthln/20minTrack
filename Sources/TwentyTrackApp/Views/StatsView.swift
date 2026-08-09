import SwiftUI
import TwentyCore

/// Root of the Statistik window: Tag | Woche. Plain @State — a fresh
/// hosting view per window open resets to Tag and reloads (Timer pattern).
struct StatsView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar
    let usageFor: (DateInterval) -> [AppUsageTotal]

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
                StatsDayView(
                    dayStore: dayStore, preferences: preferences,
                    calendar: calendar, usageFor: usageFor
                )
            case .week:
                StatsWeekView(dayStore: dayStore, preferences: preferences, calendar: calendar)
            }
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 540)
    }
}

/// One key figure ("Fokus heute" / "3 h 20 min") as a quiet tile.
struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

/// Shared stat helpers over per-label totals (stable default label ids).
enum StatsFigures {
    static func focusSeconds(_ totals: [String: TimeInterval]) -> TimeInterval {
        totals["focus-mma"] ?? 0
    }

    /// Fokus / (Fokus + Halbfokus + Ablenkung) — the work-quality ratio.
    static func focusShare(_ totals: [String: TimeInterval]) -> String {
        let focus = focusSeconds(totals)
        let basis = focus + (totals["half-focus"] ?? 0) + (totals["no-focus"] ?? 0)
        guard basis > 0 else { return "–" }
        return "\(Int((focus / basis * 100).rounded())) %"
    }
}

/// Per-label duration list with proportional color bars behind each row,
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

    private var maxSeconds: TimeInterval {
        max(rows.first?.seconds ?? 0, untrackedSeconds, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(rows, id: \.id) { row in
                barRow(
                    color: row.label.map { LabelPalette.color(for: $0.colorKey) } ?? .gray,
                    name: row.label?.name ?? "Unbekannt",
                    seconds: row.seconds,
                    share: true,
                    secondaryName: false
                )
            }
            if untrackedSeconds > 0 {
                barRow(
                    color: .gray,
                    name: "Nicht erfasst",
                    seconds: untrackedSeconds,
                    share: false,
                    secondaryName: true
                )
            }
            if rows.isEmpty && untrackedSeconds <= 0 {
                Text("Keine Einträge.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barRow(
        color: Color, name: String, seconds: TimeInterval,
        share: Bool, secondaryName: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(name)
                .lineLimit(1)
                .foregroundStyle(secondaryName ? Color.secondary : Color.primary)
            Spacer()
            durationText(seconds, share: share)
        }
        .font(.callout)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(alignment: .leading) {
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.16))
                    .frame(width: max(4, geo.size.width * seconds / maxSeconds))
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

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
        case month = "Monat"
        case year = "Jahr"
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
            .frame(maxWidth: 320)
            switch tab {
            case .day:
                StatsDayView(
                    dayStore: dayStore, preferences: preferences,
                    calendar: calendar, usageFor: usageFor
                )
            case .week:
                StatsWeekView(dayStore: dayStore, preferences: preferences, calendar: calendar)
            case .month:
                StatsMonthView(dayStore: dayStore, preferences: preferences, calendar: calendar)
            case .year:
                StatsYearView(dayStore: dayStore, preferences: preferences, calendar: calendar)
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

/// Progress bars for every label carrying a daily goal: done / target,
/// remaining time or a green "erreicht" (`goalMultiplier` = 7 in the week
/// view). Renders nothing when no active label has a goal.
struct GoalsSection: View {
    let labels: [TrackLabel]
    let totals: [String: TimeInterval]
    var goalMultiplier = 1

    private var goalLabels: [TrackLabel] {
        labels.filter { $0.goalMinutes != nil && !$0.archived }
    }

    var body: some View {
        if !goalLabels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ziele")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(goalLabels) { label in
                    goalRow(label)
                }
            }
        }
    }

    private func goalRow(_ label: TrackLabel) -> some View {
        let color = LabelPalette.color(for: label.colorKey)
        let target = TimeInterval((label.goalMinutes ?? 0) * 60 * goalMultiplier)
        let done = totals[label.id] ?? 0
        let reached = done >= target
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(label.name).lineLimit(1)
                Spacer()
                Text("\(TimeFormatting.wording(seconds: done)) / \(TimeFormatting.wording(seconds: target))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if reached {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("erreicht")
                    }
                    .foregroundStyle(Color.green)
                    .font(.caption)
                } else {
                    Text("noch \(TimeFormatting.wording(seconds: target - done))")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .font(.callout)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(reached ? Color.green : color)
                        .frame(width: max(3, geo.size.width * min(done / max(target, 1), 1)))
                }
            }
            .frame(height: 7)
        }
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

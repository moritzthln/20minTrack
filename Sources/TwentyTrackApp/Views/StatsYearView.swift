import SwiftUI
import TwentyCore

/// One calendar year: tiles, per-month bar chart per label, label totals.
/// No untracked line and no goals section — at year scale only the
/// averages and totals carry meaning.
struct StatsYearView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar

    @State private var anchorDay = Date()
    @State private var totalsByMonth: [Int: [String: TimeInterval]] = [:]
    @State private var activeDayCount = 0
    @State private var chartLabelID = "focus-mma"

    private var yearStart: Date {
        calendar.date(
            from: calendar.dateComponents([.year], from: anchorDay)
        ) ?? calendar.startOfDay(for: anchorDay)
    }

    private var year: Int {
        calendar.component(.year, from: anchorDay)
    }

    private var labelsByID: [String: TrackLabel] {
        Dictionary(
            preferences.labels.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var totals: [String: TimeInterval] {
        totalsByMonth.values.reduce(into: [:]) { result, monthTotals in
            for (id, seconds) in monthTotals {
                result[id, default: 0] += seconds
            }
        }
    }

    private var isCurrentYear: Bool {
        year == calendar.component(.year, from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                tileRow
                chartSection
                LabelTotalsList(
                    totals: totals,
                    untrackedSeconds: 0,
                    labelsByID: labelsByID
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Text(String(year))
                .font(.headline)
                .frame(minWidth: 80)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .disabled(isCurrentYear)
            Spacer()
            Text("\(activeDayCount) aktive Tage")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var tileRow: some View {
        let focus = StatsFigures.focusSeconds(totals)
        return HStack(spacing: 8) {
            StatTile(title: "Fokus", value: TimeFormatting.wording(seconds: focus))
            StatTile(
                title: "Ø Fokus/Tag",
                value: activeDayCount > 0
                    ? TimeFormatting.wording(seconds: focus / Double(activeDayCount))
                    : "–"
            )
            StatTile(title: "Fokus-Quote", value: StatsFigures.focusShare(totals))
            StatTile(
                title: "Ablenkung",
                value: TimeFormatting.wording(seconds: totals["no-focus"] ?? 0)
            )
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Jahresverlauf")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $chartLabelID) {
                    ForEach(preferences.activeLabels) { label in
                        Text(label.name).tag(label.id)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            LabelBarChart(
                values: (1...12).map { month in
                    let date = calendar.date(
                        byAdding: .month, value: month - 1, to: yearStart
                    ) ?? yearStart
                    return (date, totalsByMonth[month]?[chartLabelID] ?? 0)
                },
                color: LabelPalette.color(labelID: chartLabelID, labelsByID: labelsByID),
                goalSeconds: nil,
                axisLabel: { date, _ in
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "de_DE")
                    formatter.dateFormat = "MMMMM"
                    formatter.timeZone = calendar.timeZone
                    return formatter.string(from: date)
                }
            )
        }
    }

    private func shift(_ years: Int) {
        guard let shifted = calendar.date(byAdding: .year, value: years, to: anchorDay) else { return }
        anchorDay = shifted
        load()
    }

    /// One pass over the year's days (missing files read instantly empty).
    private func load() {
        var byMonth: [Int: [String: TimeInterval]] = [:]
        var activeDays = 0
        var cursor = yearStart
        let end = min(
            calendar.date(byAdding: .year, value: 1, to: yearStart) ?? cursor,
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? cursor
        )
        while cursor < end {
            let entries = dayStore.entries(onDay: cursor)
            if !entries.isEmpty {
                activeDays += 1
                let month = calendar.component(.month, from: cursor)
                for (id, seconds) in StatsMath.totals(entries) {
                    byMonth[month, default: [:]][id, default: 0] += seconds
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        totalsByMonth = byMonth
        activeDayCount = activeDays
    }
}

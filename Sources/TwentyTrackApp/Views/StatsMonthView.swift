import SwiftUI
import TwentyCore

/// One calendar month: tiles, per-day bar chart per label, label totals,
/// goals scaled to the month's day count. "Nicht erfasst" is computed
/// over active days only — empty days (pre-install, off days) would
/// otherwise drown every number.
struct StatsMonthView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar

    @State private var anchorDay = Date()
    @State private var entriesByDay: [Date: [Entry]] = [:]
    @State private var chartLabelID = "focus-mma"

    private var monthDays: [Date] {
        let start = monthStart
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    private var monthStart: Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: anchorDay)
        ) ?? calendar.startOfDay(for: anchorDay)
    }

    private var labelsByID: [String: TrackLabel] {
        Dictionary(
            preferences.labels.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var allEntries: [Entry] {
        entriesByDay.values.flatMap { $0 }
    }

    /// Per-day attribution folded into one month total (settled days'
    /// gaps count as Ablenkung).
    private var attribution: (totals: [String: TimeInterval], untracked: TimeInterval) {
        var totals: [String: TimeInterval] = [:]
        var untracked: TimeInterval = 0
        let now = Date()
        for day in monthDays where day <= now {
            let entries = entriesByDay[day] ?? []
            guard !entries.isEmpty else { continue }
            let result = DayAttribution.totals(
                day: day, entries: entries, now: now,
                calendar: calendar, distractionLabelID: "no-focus",
                isAbsent: AbsenceRules.isAbsent(
                    day: day, in: preferences.absences, calendar: calendar
                )
            )
            for (id, seconds) in result.totals {
                totals[id, default: 0] += seconds
            }
            untracked += result.untracked
        }
        return (totals, untracked)
    }

    private var totals: [String: TimeInterval] {
        attribution.totals
    }

    private var activeDayCount: Int {
        monthDays.filter { !(entriesByDay[$0] ?? []).isEmpty }.count
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(anchorDay, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                tileRow
                AbsenceSummaryLine(
                    days: monthDays, absences: preferences.absences, calendar: calendar
                )
                chartSection
                GoalsSection(
                    labels: preferences.labels, totals: totals,
                    goalMultiplier: monthDays.count
                )
                LabelTotalsList(
                    totals: totals,
                    untrackedSeconds: attribution.untracked,
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
            Text(monthTitle)
                .font(.headline)
                .frame(minWidth: 150)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
            Spacer()
            Text("\(activeDayCount) aktive Tage")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: monthStart)
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
                Text("Monatsverlauf")
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
                values: monthDays.map { day in
                    (day, StatsMath.totals(entriesByDay[day] ?? [])[chartLabelID] ?? 0)
                },
                color: LabelPalette.color(labelID: chartLabelID, labelsByID: labelsByID),
                goalSeconds: labelsByID[chartLabelID]?.goalMinutes.map { TimeInterval($0 * 60) },
                axisLabel: { day, index in
                    let number = calendar.component(.day, from: day)
                    return index == 0 || number % 5 == 0 ? "\(number)" : ""
                }
            )
        }
    }

    private func shift(_ months: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: months, to: anchorDay) else { return }
        anchorDay = shifted
        load()
    }

    private func load() {
        entriesByDay = Dictionary(uniqueKeysWithValues: monthDays.map {
            ($0, dayStore.entries(onDay: $0))
        })
    }
}

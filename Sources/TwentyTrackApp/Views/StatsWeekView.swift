import SwiftUI
import TwentyCore

/// One ISO week: navigation, seven mini strips (Mon–Sun), label totals.
struct StatsWeekView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar

    @State private var anchorDay = Date()
    @State private var entriesByDay: [Date: [Entry]] = [:]
    @State private var fazitByDay: [Date: String] = [:]
    /// "all" = stacked composition of every label; a label id = that
    /// label's bars with its goal line.
    @State private var chartLabelID = "all"
    @State private var chartIncludesSleep = false

    private var weekDays: [Date] {
        StatsMath.weekDays(containing: anchorDay, calendar: calendar)
    }

    private var labelsByID: [String: TrackLabel] {
        Dictionary(
            preferences.labels.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var isCurrentWeek: Bool {
        StatsMath.weekDays(containing: Date(), calendar: calendar).first == weekDays.first
    }

    private var allEntries: [Entry] {
        entriesByDay.values.flatMap { $0 }
    }

    /// Per-day attribution folded into one week total (settled days'
    /// gaps count as Ablenkung).
    private var attribution: (totals: [String: TimeInterval], untracked: TimeInterval) {
        var totals: [String: TimeInterval] = [:]
        var untracked: TimeInterval = 0
        for day in weekDays {
            guard let result = dayAttribution(day) else { continue }
            for (id, seconds) in result.totals {
                totals[id, default: 0] += seconds
            }
            untracked += result.untracked
        }
        return (totals, untracked)
    }

    /// Attributed totals of one day; nil for days still in the future.
    private func dayAttribution(_ day: Date) -> (totals: [String: TimeInterval], untracked: TimeInterval)? {
        let now = Date()
        guard day <= now else { return nil }
        return DayAttribution.totals(
            day: day, entries: entriesByDay[day] ?? [], now: now,
            calendar: calendar, distractionLabelID: "no-focus",
            isAbsent: isAbsent(day)
        )
    }

    private func isAbsent(_ day: Date) -> Bool {
        AbsenceRules.isAbsent(day: day, in: preferences.absences, calendar: calendar)
    }

    private var compositions: [WeekDayComposition] {
        weekDays.map { day in
            WeekDayComposition(
                id: day, shortName: weekdayShort(day),
                totals: dayAttribution(day)?.totals ?? [:],
                isAbsent: isAbsent(day)
            )
        }
    }

    private var totals: [String: TimeInterval] {
        attribution.totals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                tileRow
                AbsenceSummaryLine(
                    days: weekDays, absences: preferences.absences, calendar: calendar
                )
                GoalsSection(labels: preferences.labels, totals: totals, goalMultiplier: 7)
                chartSection
                dayRows
                LabelTotalsList(
                    totals: totals,
                    untrackedSeconds: attribution.untracked,
                    labelsByID: labelsByID
                )
                fazitList
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: load)
    }

    private var tileRow: some View {
        let focus = StatsFigures.focusSeconds(totals)
        let activeDays = weekDays.filter { !(entriesByDay[$0] ?? []).isEmpty }.count
        return HStack(spacing: 8) {
            StatTile(title: loc("Fokus", "Focus"), value: TimeFormatting.wording(seconds: focus))
            StatTile(
                title: loc("Ø Fokus/Tag", "Ø focus/day"),
                value: activeDays > 0
                    ? TimeFormatting.wording(seconds: focus / Double(activeDays))
                    : "–"
            )
            StatTile(title: loc("Fokus-Quote", "Focus ratio"), value: StatsFigures.focusShare(totals))
            StatTile(
                title: loc("Ablenkung", "Distraction"),
                value: TimeFormatting.wording(seconds: totals["no-focus"] ?? 0)
            )
        }
    }

    /// Bar chart of one label's hours per weekday, with the daily goal as
    /// a reference line. The picker switches the label.
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(loc("Wochenverlauf", "Week trend"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $chartLabelID) {
                    Text(loc("Alle Labels", "All labels")).tag("all")
                    Divider()
                    ForEach(preferences.activeLabels) { label in
                        Text(label.name).tag(label.id)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
                if chartLabelID == "all" {
                    Toggle(loc("Schlaf zeigen", "Show sleep"), isOn: $chartIncludesSleep)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
            if chartLabelID == "all" {
                WeekCompositionChart(
                    days: compositions, labels: preferences.labels,
                    labelsByID: labelsByID, includeSleep: chartIncludesSleep
                )
            } else {
                labelChart
            }
        }
    }

    private var labelChart: some View {
            LabelBarChart(
                values: weekDays.map { day in
                    (day, StatsMath.totals(entriesByDay[day] ?? [])[chartLabelID] ?? 0)
                },
                color: LabelPalette.color(labelID: chartLabelID, labelsByID: labelsByID),
                goalSeconds: labelsByID[chartLabelID]?.goalMinutes.map { TimeInterval($0 * 60) },
                showValues: true,
                axisLabel: { day, _ in weekdayShort(day) }
            )
    }

    /// The week's daily conclusions — the written review in one place.
    private var fazitList: some View {
        let fazite = weekDays.compactMap { day in
            fazitByDay[day].map { (day: day, text: $0) }
        }
        return VStack(alignment: .leading, spacing: 4) {
            if !fazite.isEmpty {
                Text(loc("Fazite", "Reviews"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(fazite, id: \.day) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(weekdayShort(item.day))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)
                        Text(item.text)
                            .lineLimit(3)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { shift(-7) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Text(weekTitle)
                .font(.headline)
                .frame(minWidth: 170)
            Button { shift(7) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .disabled(isCurrentWeek)
            Spacer()
            Text(TimeFormatting.wording(seconds: StatsMath.trackedSeconds(allEntries)))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var weekTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        var isoCalendar = Calendar(identifier: .iso8601)
        isoCalendar.timeZone = calendar.timeZone
        let week = isoCalendar.component(.weekOfYear, from: first)
        let formatter = DateFormatter()
        formatter.locale = l10nLocale
        formatter.dateFormat = loc("d. MMM", "MMM d")
        formatter.timeZone = calendar.timeZone
        return loc("KW", "Week") + " \(week) · \(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    private var dayRows: some View {
        VStack(spacing: 5) {
            ForEach(weekDays, id: \.self) { day in
                let entries = entriesByDay[day] ?? []
                HStack(spacing: 8) {
                    Text(weekdayShort(day))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .leading)
                    DayStripView(
                        day: day,
                        entries: entries,
                        labelsByID: labelsByID,
                        calendar: calendar,
                        now: calendar.isDate(day, inSameDayAs: Date()) ? Date() : nil,
                        height: 14
                    )
                    dayRowTrailing(day: day, entries: entries)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
    }

    /// The day's sum — or, on an entry-less absent day, WHICH absence.
    @ViewBuilder
    private func dayRowTrailing(day: Date, entries: [Entry]) -> some View {
        if entries.isEmpty,
           let absence = AbsenceRules.absence(
               containing: day, in: preferences.absences, calendar: calendar
           ) {
            Text(absence.name)
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(1)
        } else {
            Text(TimeFormatting.wording(seconds: StatsMath.trackedSeconds(entries)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    fileprivate func weekdayShort(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = l10nLocale
        formatter.dateFormat = "EE"
        formatter.timeZone = calendar.timeZone
        return String(formatter.string(from: day).prefix(2))
    }

    private func shift(_ days: Int) {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: anchorDay) else { return }
        anchorDay = shifted
        load()
    }

    private func load() {
        entriesByDay = Dictionary(uniqueKeysWithValues: weekDays.map {
            ($0, dayStore.entries(onDay: $0))
        })
        fazitByDay = weekDays.reduce(into: [:]) { result, day in
            result[day] = dayStore.fazit(onDay: day)
        }
    }
}


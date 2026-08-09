import SwiftUI
import TwentyCore

/// One ISO week: navigation, seven mini strips (Mon–Sun), label totals.
struct StatsWeekView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar

    @State private var anchorDay = Date()
    @State private var entriesByDay: [Date: [Entry]] = [:]

    private var weekDays: [Date] {
        StatsMath.weekDays(containing: anchorDay, calendar: calendar)
    }

    private var labelsByID: [String: TrackLabel] {
        Dictionary(uniqueKeysWithValues: preferences.labels.map { ($0.id, $0) })
    }

    private var isCurrentWeek: Bool {
        StatsMath.weekDays(containing: Date(), calendar: calendar).first == weekDays.first
    }

    private var allEntries: [Entry] {
        entriesByDay.values.flatMap { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                dayRows
                LabelTotalsList(
                    totals: StatsMath.totals(allEntries),
                    untrackedSeconds: untrackedWeekSeconds,
                    labelsByID: labelsByID
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: load)
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
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMM"
        formatter.timeZone = calendar.timeZone
        return "KW \(week) · \(formatter.string(from: first)) – \(formatter.string(from: last))"
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
                    Text(TimeFormatting.wording(seconds: StatsMath.trackedSeconds(entries)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
    }

    private var untrackedWeekSeconds: TimeInterval {
        weekDays.reduce(0) { sum, day in
            guard day <= Date() else { return sum }
            return sum + StatsMath.untrackedSeconds(
                day: day, reference: Date(), entries: entriesByDay[day] ?? [], calendar: calendar
            )
        }
    }

    private func weekdayShort(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
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
    }
}

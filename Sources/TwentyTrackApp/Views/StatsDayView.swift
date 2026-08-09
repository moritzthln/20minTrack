import SwiftUI
import TwentyCore

/// One day: navigation, strip with hour marks, per-label totals, Fazit.
struct StatsDayView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar

    @State private var day = Date()
    @State private var entries: [Entry] = []
    @State private var fazitDraft = ""
    @State private var savedFazit = ""

    private var labelsByID: [String: TrackLabel] {
        Dictionary(uniqueKeysWithValues: preferences.labels.map { ($0.id, $0) })
    }

    private var isToday: Bool {
        calendar.isDate(day, inSameDayAs: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                stripSection
                LabelTotalsList(
                    totals: StatsMath.totals(entries),
                    untrackedSeconds: StatsMath.untrackedSeconds(
                        day: day, reference: Date(), entries: entries, calendar: calendar
                    ),
                    labelsByID: labelsByID
                )
                fazitSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
            Text(dayTitle)
                .font(.headline)
                .frame(minWidth: 150)
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .disabled(isToday)
            Spacer()
            Text(TimeFormatting.wording(seconds: StatsMath.trackedSeconds(entries)))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEE, d. MMMM"
        formatter.timeZone = calendar.timeZone
        return isToday ? "Heute" : formatter.string(from: day)
    }

    private var stripSection: some View {
        VStack(spacing: 2) {
            DayStripView(
                day: day,
                entries: entries,
                labelsByID: labelsByID,
                calendar: calendar,
                now: isToday ? Date() : nil,
                height: 26
            )
            HStack {
                ForEach(["0", "6", "12", "18", "24"], id: \.self) { mark in
                    Text(mark)
                    if mark != "24" { Spacer() }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var fazitSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tagesfazit")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $fazitDraft)
                .font(.body)
                .frame(minHeight: 64, maxHeight: 110)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
            HStack {
                Spacer()
                Button("Fazit speichern") {
                    dayStore.setFazit(fazitDraft, onDay: day)
                    savedFazit = fazitDraft
                }
                .disabled(fazitDraft == savedFazit)
            }
        }
    }

    private func shift(_ days: Int) {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: day) else { return }
        day = min(shifted, Date())
        load()
    }

    private func load() {
        entries = dayStore.entries(onDay: day)
        savedFazit = dayStore.fazit(onDay: day) ?? ""
        fazitDraft = savedFazit
    }
}

import SwiftUI
import TwentyCore

/// One day: navigation, clickable strip (backfill editor), per-label
/// totals, Fazit.
struct StatsDayView: View {
    let dayStore: DayStore
    let preferences: Preferences
    let calendar: Calendar
    let usageFor: (DateInterval) -> [AppUsageTotal]

    private struct EditTarget: Identifiable {
        let id = UUID()
        let slot: DateInterval
        let existing: Entry?
    }

    @State private var day = Date()
    @State private var entries: [Entry] = []
    @State private var fazitDraft = ""
    @State private var savedFazit = ""
    @State private var editTarget: EditTarget?

    private var labelsByID: [String: TrackLabel] {
        Dictionary(
            preferences.labels.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var isToday: Bool {
        calendar.isDate(day, inSameDayAs: Date())
    }

    private var totals: [String: TimeInterval] {
        StatsMath.totals(entries)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                tileRow
                stripSection
                LabelTotalsList(
                    totals: totals,
                    untrackedSeconds: StatsMath.untrackedSeconds(
                        day: day, reference: Date(), entries: entries, calendar: calendar
                    ),
                    labelsByID: labelsByID
                )
                entryList
                fazitSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: load)
        .sheet(item: $editTarget) { target in
            SlotEditView(
                day: day,
                slot: target.slot,
                existing: target.existing,
                labels: preferences.activeLabels,
                calendar: calendar,
                preselectedLabelID: preferences.lastLabelID,
                usageFor: usageFor,
                onSave: { start, end, labelID, text in
                    if let existing = target.existing {
                        dayStore.remove(id: existing.id, onDay: day)
                    }
                    dayStore.insert(start: start, end: end, labelID: labelID, text: text)
                    preferences.lastLabelID = labelID
                    finishEdit()
                },
                onDelete: {
                    if let existing = target.existing {
                        dayStore.remove(id: existing.id, onDay: day)
                    }
                    finishEdit()
                },
                onCancel: { editTarget = nil }
            )
            .padding(16)
            .frame(width: 320)
        }
    }

    private func finishEdit() {
        editTarget = nil
        load()
        // Today edited here → menu bar / popover must reload (anchor advance).
        NotificationCenter.default.post(name: .trackerSettingsChanged, object: nil)
    }

    private func entry(at slot: DateInterval) -> Entry? {
        let mid = slot.start.addingTimeInterval(slot.duration / 2)
        return entries.first { $0.start <= mid && mid < $0.end }
    }

    /// A tapped empty slot expands to the whole surrounding untracked gap
    /// (capped at the running block when viewing today).
    private func expandedSlot(_ slot: DateInterval) -> DateInterval {
        guard entry(at: slot) == nil else { return slot }
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return slot }
        let blocked = entries.map { DateInterval(start: $0.start, end: $0.end) }
        let mid = slot.start.addingTimeInterval(slot.duration / 2)
        guard var gap = GapFill.gaps(in: DateInterval(start: dayStart, end: dayEnd), blocked: blocked)
            .first(where: { $0.start <= mid && mid < $0.end }) else { return slot }
        if isToday {
            let cap = max(slot.end, SlotGrid.floorBoundary(Date(), calendar: calendar))
            if gap.end > cap {
                gap = DateInterval(start: gap.start, end: cap)
            }
        }
        return gap.duration > 0 ? gap : slot
    }

    private var tileRow: some View {
        HStack(spacing: 8) {
            StatTile(
                title: "Fokus",
                value: TimeFormatting.wording(seconds: StatsFigures.focusSeconds(totals))
            )
            StatTile(title: "Fokus-Quote", value: StatsFigures.focusShare(totals))
            StatTile(
                title: "Getrackt",
                value: TimeFormatting.wording(seconds: StatsMath.trackedSeconds(entries))
            )
        }
    }

    /// Chronological entries with their notes — click to edit.
    private var entryList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !entries.isEmpty {
                Text("Einträge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            }
        }
    }

    private func entryRow(_ entry: Entry) -> some View {
        Button {
            editTarget = EditTarget(
                slot: DateInterval(start: entry.start, end: entry.end), existing: entry
            )
        } label: {
            HStack(spacing: 6) {
                Text("\(TimeFormatting.clock(entry.start, calendar: calendar))–\(TimeFormatting.clock(entry.end, calendar: calendar))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 88, alignment: .leading)
                Circle()
                    .fill(LabelPalette.color(labelID: entry.labelID, labelsByID: labelsByID))
                    .frame(width: 7, height: 7)
                Text(labelsByID[entry.labelID]?.name ?? "Unbekannt")
                    .lineLimit(1)
                if !entry.text.isEmpty {
                    Text("· \(entry.text)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Eintrag bearbeiten")
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
                height: 26,
                onTapSlot: { slot in
                    editTarget = EditTarget(slot: expandedSlot(slot), existing: entry(at: slot))
                }
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

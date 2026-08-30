import SwiftUI
import TwentyCore

/// Editor for one span of today — fill an empty slot, relabel, or delete.
struct SlotEditView: View {
    let day: Date
    let slot: DateInterval
    let existing: Entry?
    let labels: [TrackLabel]
    let calendar: Calendar
    let preselectedLabelID: String?
    let usageFor: (DateInterval) -> [AppUsageTotal]
    let onSave: (
        _ start: Date, _ end: Date, _ labelID: String,
        _ secondLabelID: String?, _ text: String
    ) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var from = Date.distantPast
    @State private var to = Date.distantPast
    @State private var text = ""
    /// Ordered, max two: [primary] or [primary, second] (10/10 split).
    @State private var selection: [String] = []
    @State private var usage: [AppUsageTotal] = []

    private var dayBoundaries: [Date] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return SlotGrid.boundaries(from: dayStart, to: dayEnd, calendar: calendar)
    }

    private var fromOptions: [Date] { Array(dayBoundaries.dropLast()) }
    private var toOptions: [Date] { dayBoundaries.filter { $0 > from } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(existing == nil ? loc("Block eintragen", "Log block") : loc("Block bearbeiten", "Edit block"))
                .font(.headline)
            HStack(spacing: 4) {
                Text(loc("Von", "From"))
                timePicker(selection: $from, options: fromOptions)
                Text(loc("bis", "until"))
                timePicker(selection: $to, options: toOptions)
            }
            .font(.caption)
            UsageLineView(usage: usage)
            TextField(loc("Kurz notieren… (optional)", "Quick note… (optional)"), text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }
            LabelChipsView(labels: labels, selection: $selection)
            if selection.count == 2 {
                Text(loc("Jeder 20-Minuten-Block wird geteilt: 10 min je Label", "Each 20-minute block is split: 10 min per label"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                if existing != nil {
                    Button(loc("Löschen", "Delete"), role: .destructive, action: onDelete)
                        .buttonStyle(PillButtonStyle())
                }
                Spacer()
                Button(loc("Abbrechen", "Cancel"), action: onCancel)
                    .buttonStyle(PillButtonStyle())
                Button(loc("Speichern", "Save")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection.isEmpty || to <= from)
            }
        }
        .onAppear {
            prefill()
            reloadUsage()
        }
        .onChange(of: from) { newFrom in
            if to <= newFrom {
                to = SlotGrid.nextBoundary(after: newFrom, calendar: calendar)
            }
            reloadUsage()
        }
        .onChange(of: to) { _ in reloadUsage() }
    }

    private func timePicker(selection: Binding<Date>, options: [Date]) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.self) { option in
                Text(timeLabel(option)).tag(option)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    /// The day-end boundary reads "24:00", not "00:00" of the next day.
    private func timeLabel(_ date: Date) -> String {
        if date == dayBoundaries.last {
            return "24:00"
        }
        return TimeFormatting.clock(date, calendar: calendar)
    }

    private func reloadUsage() {
        guard to > from else {
            usage = []
            return
        }
        usage = usageFor(DateInterval(start: from, end: to))
    }

    private func save() {
        guard let primary = selection.first, to > from else { return }
        onSave(from, to, primary, selection.count > 1 ? selection[1] : nil, text)
    }

    private func prefill() {
        if let existing {
            from = existing.start
            to = existing.end
            text = existing.text
            selection = [existing.labelID]
        } else {
            from = slot.start
            to = slot.end
            selection = labels.contains { $0.id == preselectedLabelID }
                ? [preselectedLabelID].compactMap { $0 } : []
        }
    }
}

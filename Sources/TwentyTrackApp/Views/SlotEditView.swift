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
    @State private var selectedLabelID: String?
    @State private var secondLabelID: String?
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
            Text(existing == nil ? "Block eintragen" : "Block bearbeiten")
                .font(.headline)
            HStack(spacing: 4) {
                Text("Von")
                timePicker(selection: $from, options: fromOptions)
                Text("bis")
                timePicker(selection: $to, options: toOptions)
            }
            .font(.caption)
            UsageLineView(usage: usage)
            TextField("Kurz notieren… (optional)", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save(labelID: selectedLabelID) }
            LabelChipsView(
                labels: labels,
                selectedID: $selectedLabelID,
                onConfirm: { save(labelID: $0) }
            )
            SecondLabelRow(
                labels: labels, primaryID: selectedLabelID, secondID: $secondLabelID
            )
            HStack {
                if existing != nil {
                    Button("Löschen", role: .destructive, action: onDelete)
                        .buttonStyle(PillButtonStyle())
                }
                Spacer()
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(PillButtonStyle())
                Button("Speichern") { save(labelID: selectedLabelID) }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedLabelID == nil || to <= from)
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

    private func save(labelID: String?) {
        guard let labelID, to > from else { return }
        onSave(from, to, labelID, secondLabelID == labelID ? nil : secondLabelID, text)
    }

    private func prefill() {
        if let existing {
            from = existing.start
            to = existing.end
            text = existing.text
            selectedLabelID = existing.labelID
        } else {
            from = slot.start
            to = slot.end
            selectedLabelID = labels.contains { $0.id == preselectedLabelID }
                ? preselectedLabelID : nil
        }
    }
}

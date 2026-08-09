import SwiftUI
import TwentyCore

/// Editor for one span of today — fill an empty slot, relabel, or delete.
struct SlotEditView: View {
    let day: Date
    let slot: DateInterval
    let existing: Entry?
    let labels: [TrackLabel]
    let calendar: Calendar
    let onSave: (_ start: Date, _ end: Date, _ labelID: String, _ text: String) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var from = Date.distantPast
    @State private var to = Date.distantPast
    @State private var text = ""
    @State private var selectedLabelID: String?

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
            TextField("Kurz notieren…", text: $text)
                .textFieldStyle(.roundedBorder)
            LabelChipsView(labels: labels, selectedID: $selectedLabelID)
            HStack {
                if existing != nil {
                    Button("Löschen", role: .destructive, action: onDelete)
                        .buttonStyle(PillButtonStyle())
                }
                Spacer()
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(PillButtonStyle())
                Button("Speichern") {
                    guard let selectedLabelID, to > from else { return }
                    onSave(from, to, selectedLabelID, text)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedLabelID == nil || to <= from)
            }
        }
        .onAppear(perform: prefill)
        .onChange(of: from) { newFrom in
            if to <= newFrom {
                to = SlotGrid.nextBoundary(after: newFrom, calendar: calendar)
            }
        }
    }

    private func timePicker(selection: Binding<Date>, options: [Date]) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.self) { option in
                Text(TimeFormatting.clock(option, calendar: calendar)).tag(option)
            }
        }
        .labelsHidden()
        .fixedSize()
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
        }
    }
}

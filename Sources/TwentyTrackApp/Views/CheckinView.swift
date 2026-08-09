import SwiftUI
import TwentyCore

/// The 20-minute prompt: what happened, which label, over which span.
struct CheckinView: View {
    let pending: DateInterval
    let labels: [TrackLabel]
    let calendar: Calendar
    let usageFor: (DateInterval) -> [AppUsageTotal]
    let onSave: (_ from: Date, _ labelID: String, _ text: String) -> Void
    let onSkip: () -> Void

    @State private var fromDate = Date.distantPast
    @State private var text = ""
    @State private var selectedLabelID: String?
    @State private var usage: [AppUsageTotal] = []
    @FocusState private var textFocused: Bool

    /// Selectable span starts: every boundary in the window except its end.
    private var startOptions: [Date] {
        SlotGrid.boundaries(from: pending.start, to: pending.end, calendar: calendar)
            .dropLast()
            .map { $0 }
    }

    private var effectiveFrom: Date {
        startOptions.contains(fromDate) ? fromDate : pending.start
    }

    private var blockCount: Int {
        SlotGrid.blockCount(start: effectiveFrom, end: pending.end, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Was hast du gemacht?")
                .font(.headline)
            spanLine
            UsageLineView(usage: usage)
            TextField("Kurz notieren…", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($textFocused)
                .onSubmit(save)
            LabelChipsView(labels: labels, selectedID: $selectedLabelID)
            HStack {
                Button("Überspringen", action: onSkip)
                    .buttonStyle(PillButtonStyle())
                Spacer()
                Button("Speichern", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedLabelID == nil)
            }
        }
        .onAppear {
            fromDate = pending.start
            textFocused = true
            reloadUsage()
        }
        // Reset drafts only when the span START moves (anchor changed).
        // A growing END (boundary fired while typing) must not wipe input.
        .onChange(of: pending.start) { newStart in
            fromDate = newStart
            text = ""
            selectedLabelID = nil
        }
        .onChange(of: pending) { _ in reloadUsage() }
        .onChange(of: fromDate) { _ in reloadUsage() }
    }

    private func reloadUsage() {
        usage = usageFor(DateInterval(start: effectiveFrom, end: pending.end))
    }

    private var spanLine: some View {
        HStack(spacing: 4) {
            if startOptions.count > 1 {
                Text("Von")
                Picker("Von", selection: $fromDate) {
                    ForEach(startOptions, id: \.self) { option in
                        Text(TimeFormatting.clock(option, calendar: calendar)).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
            } else {
                Text(TimeFormatting.clock(pending.start, calendar: calendar))
            }
            Text("bis \(TimeFormatting.clock(pending.end, calendar: calendar))")
            Text("· \(blockCount) \(blockCount == 1 ? "Block" : "Blöcke")")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func save() {
        guard let selectedLabelID else { return }
        onSave(effectiveFrom, selectedLabelID, text)
    }
}

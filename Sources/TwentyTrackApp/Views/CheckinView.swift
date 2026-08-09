import SwiftUI
import TwentyCore

/// The 20-minute prompt: what happened, which label, over which span.
/// Fast paths: the last label is preselected (Return saves), clicking the
/// selected chip saves, ⌘1–⌘9 pick a label and save immediately.
/// "Später" closes without settling — the span stays pending, nothing is
/// ever silently dropped.
struct CheckinView: View {
    let pending: DateInterval
    let labels: [TrackLabel]
    let calendar: Calendar
    let todayLine: String?
    let lastText: String?
    let preselectedLabelID: String?
    let usageFor: (DateInterval) -> [AppUsageTotal]
    let onSave: (_ from: Date, _ labelID: String, _ text: String) -> Void
    let onPostpone: () -> Void

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

    private var validPreselect: String? {
        labels.contains { $0.id == preselectedLabelID } ? preselectedLabelID : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Was hast du gemacht?")
                .font(.headline)
            spanLine
            if let todayLine {
                Text("Heute: \(todayLine)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            UsageLineView(usage: usage)
            TextField("Kurz notieren… (optional)", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($textFocused)
                .onSubmit { save(labelID: selectedLabelID) }
            if let lastText, text.isEmpty {
                Button {
                    text = lastText
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("„\(lastText)“")
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Letzten Text übernehmen")
            }
            LabelChipsView(
                labels: labels,
                selectedID: $selectedLabelID,
                onConfirm: { save(labelID: $0) }
            )
            HStack {
                Button("Später", action: onPostpone)
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .help("Esc — fragt beim nächsten Check-in wieder mit ab")
                Spacer()
                Button("Speichern") { save(labelID: selectedLabelID) }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedLabelID == nil)
                    .help("⏎ speichert · ⌘1–⌘9 wählt ein Label und speichert sofort")
            }
            shortcutButtons
        }
        .onAppear {
            fromDate = pending.start
            selectedLabelID = validPreselect
            textFocused = true
            reloadUsage()
        }
        // Reset drafts only when the span START moves (anchor changed).
        // A growing END (boundary fired while typing) must not wipe input.
        .onChange(of: pending.start) { newStart in
            fromDate = newStart
            text = ""
            selectedLabelID = validPreselect
        }
        .onChange(of: pending) { _ in reloadUsage() }
        .onChange(of: fromDate) { _ in reloadUsage() }
    }

    /// Invisible buttons carrying ⌘1–⌘9: pick the n-th label and save.
    private var shortcutButtons: some View {
        ForEach(Array(labels.prefix(9).enumerated()), id: \.element.id) { index, label in
            Button("") { save(labelID: label.id) }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(index + 1)")), modifiers: .command
                )
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
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

    private func reloadUsage() {
        usage = usageFor(DateInterval(start: effectiveFrom, end: pending.end))
    }

    private func save(labelID: String?) {
        guard let labelID else { return }
        onSave(effectiveFrom, labelID, text)
    }
}

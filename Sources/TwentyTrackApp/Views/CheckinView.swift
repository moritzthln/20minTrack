import SwiftUI
import TwentyCore

/// The 20-minute prompt: what happened, which label, over which span.
/// Fast paths: the last label is preselected (Return saves), clicking the
/// selected chip saves, ⌘1–⌘9 and ⌘0 (10th label) pick and save immediately.
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
    let onSave: (
        _ from: Date, _ to: Date, _ labelID: String,
        _ secondLabelID: String?, _ text: String
    ) -> Void
    let onPostpone: () -> Void

    @State private var fromDate = Date.distantPast
    @State private var toDate = Date.distantFuture
    @State private var text = ""
    /// Ordered, max two: [primary] or [primary, second] (10/10 split).
    @State private var selection: [String] = []
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

    /// Selectable span ends: every boundary after the chosen start.
    private var endOptions: [Date] {
        SlotGrid.boundaries(from: effectiveFrom, to: pending.end, calendar: calendar)
            .filter { $0 > effectiveFrom }
    }

    private var effectiveTo: Date {
        endOptions.contains(toDate) ? toDate : pending.end
    }

    private var blockCount: Int {
        SlotGrid.blockCount(start: effectiveFrom, end: effectiveTo, calendar: calendar)
    }

    private var validPreselect: String? {
        labels.contains { $0.id == preselectedLabelID } ? preselectedLabelID : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc("Was hast du gemacht?", "What did you do?"))
                .font(.headline)
            spanLine
            if let todayLine {
                Text(loc("Heute: ", "Today: ") + todayLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            UsageLineView(usage: usage)
            TextField(loc("Kurz notieren… (optional)", "Quick note… (optional)"), text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($textFocused)
                .onSubmit { save() }
            if let lastText, text.isEmpty {
                Button {
                    text = lastText
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text(loc("„\(lastText)“", "“\(lastText)”"))
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(loc("Letzten Text übernehmen", "Reuse the last note"))
            }
            LabelChipsView(labels: labels, selection: $selection)
            if selection.count == 2 {
                Text(loc("Jeder 20-Minuten-Block wird geteilt: 10 min je Label", "Each 20-minute block is split: 10 min per label"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button(loc("Später", "Later"), action: onPostpone)
                    .buttonStyle(PillButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .help(loc("Esc — fragt beim nächsten Check-in wieder mit ab", "Esc — will be asked again at the next check-in"))
                Spacer()
                Button(loc("Speichern", "Save")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection.isEmpty)
                    .help(loc("⏎ speichert · ⌘1–⌘9/⌘0 wählt ein Label und speichert sofort", "⏎ saves · ⌘1–⌘9/⌘0 picks a label and saves immediately"))
            }
            shortcutButtons
        }
        .onAppear {
            fromDate = pending.start
            toDate = pending.end
            selection = validPreselect.map { [$0] } ?? []
            textFocused = true
            reloadUsage()
        }
        // Reset drafts only when the span START moves (anchor changed).
        // A growing END (boundary fired while typing) must not wipe input.
        .onChange(of: pending.start) { newStart in
            fromDate = newStart
            text = ""
            selection = validPreselect.map { [$0] } ?? []
        }
        // The window stays open after a partial save: clamp both pickers
        // back into whatever range is still pending.
        .onChange(of: pending) { newValue in
            if !startOptions.contains(fromDate) { fromDate = newValue.start }
            if !endOptions.contains(toDate) { toDate = newValue.end }
            reloadUsage()
        }
        .onChange(of: fromDate) { _ in
            if !endOptions.contains(toDate) { toDate = pending.end }
            reloadUsage()
        }
        .onChange(of: toDate) { _ in reloadUsage() }
    }

    /// Invisible buttons carrying ⌘1–⌘9 plus ⌘0 for the 10th label:
    /// pick the n-th label and save.
    private var shortcutButtons: some View {
        ForEach(Array(labels.prefix(10).enumerated()), id: \.element.id) { index, label in
            Button("") { saveDirect(labelID: label.id) }
                .keyboardShortcut(
                    KeyEquivalent(Character(index == 9 ? "0" : "\(index + 1)")),
                    modifiers: .command
                )
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private var spanLine: some View {
        HStack(spacing: 4) {
            if startOptions.count > 1 {
                Text(loc("Von", "From"))
                Picker("Von", selection: $fromDate) {
                    ForEach(startOptions, id: \.self) { option in
                        Text(TimeFormatting.clock(option, calendar: calendar)).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Text(loc("bis", "until"))
                Picker("Bis", selection: $toDate) {
                    ForEach(endOptions, id: \.self) { option in
                        Text(TimeFormatting.clock(option, calendar: calendar)).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
            } else {
                Text(TimeFormatting.clock(pending.start, calendar: calendar))
                Text(loc("bis", "until") + " \(TimeFormatting.clock(pending.end, calendar: calendar))")
            }
            Text("· \(blockCount) " + (blockCount == 1 ? loc("Block", "block") : loc("Blöcke", "blocks")))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func reloadUsage() {
        guard effectiveTo > effectiveFrom else { return }
        usage = usageFor(DateInterval(start: effectiveFrom, end: effectiveTo))
    }

    /// Saves the current chip selection (one label, or two split 10/10)
    /// and clears the draft — the span may only be a part of the pending
    /// window, the rest keeps being asked.
    private func save() {
        guard let primary = selection.first else { return }
        onSave(
            effectiveFrom, effectiveTo, primary,
            selection.count > 1 ? selection[1] : nil, text
        )
        text = ""
        selection = validPreselect.map { [$0] } ?? []
    }

    /// ⌘1–⌘9/⌘0: express lane — that single label, saved immediately.
    private func saveDirect(labelID: String) {
        onSave(effectiveFrom, effectiveTo, labelID, nil, text)
        text = ""
    }
}

import SwiftUI
import TwentyCore

/// Root of the popover: check-in or idle state, today's strip, footer.
/// A fresh hosting controller per open resets the local mode.
struct PopoverRootView: View {
    @ObservedObject var model: TrackerViewModel
    let onOpenStats: () -> Void
    let onOpenSettings: () -> Void

    private enum Mode: Equatable {
        case auto
        case edit(slot: DateInterval, existing: Entry?)
        case fazit
    }

    @State private var mode: Mode = .auto

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            todaySection
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .auto:
            if let pending = model.pending {
                CheckinView(
                    pending: pending,
                    labels: model.activeLabels,
                    calendar: model.calendar,
                    onSave: { from, labelID, text in
                        model.saveCheckin(from: from, labelID: labelID, text: text)
                    },
                    onSkip: { model.skipCheckin() }
                )
            } else {
                IdleView(calendar: model.calendar, paused: model.preferences.trackingPaused)
            }
        case .edit(let slot, let existing):
            SlotEditView(
                day: slot.start,
                slot: slot,
                existing: existing,
                labels: model.activeLabels,
                calendar: model.calendar,
                onSave: { start, end, labelID, text in
                    model.replaceEntry(
                        originalID: existing?.id, day: slot.start,
                        start: start, end: end, labelID: labelID, text: text
                    )
                    mode = .auto
                },
                onDelete: {
                    if let existing {
                        model.deleteEntry(id: existing.id, day: slot.start)
                    }
                    mode = .auto
                },
                onCancel: { mode = .auto }
            )
        case .fazit:
            FazitView(
                initial: model.todayFazit,
                onSave: { text in
                    model.setTodayFazit(text)
                    mode = .auto
                },
                onCancel: { mode = .auto }
            )
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Heute")
                Spacer()
                Text(TimeFormatting.wording(seconds: StatsMath.trackedSeconds(model.todayEntries)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            DayStripView(
                day: Date(),
                entries: model.todayEntries,
                labelsByID: model.labelsByID,
                calendar: model.calendar,
                now: Date(),
                height: 20,
                onTapSlot: { slot in
                    mode = .edit(slot: slot, existing: entry(at: slot))
                }
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            footerButton("square.and.pencil", help: "Tagesfazit") { mode = .fazit }
            footerButton("chart.bar", help: "Statistik", action: onOpenStats)
            Spacer()
            Menu {
                Button(model.preferences.trackingPaused ? "Tracking fortsetzen" : "Tracking pausieren") {
                    model.togglePause()
                }
                Button("Einstellungen…", action: onOpenSettings)
                Divider()
                Button("20minTrack beenden") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .font(.system(size: 14))
    }

    private func footerButton(
        _ symbol: String, help: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func entry(at slot: DateInterval) -> Entry? {
        let mid = slot.start.addingTimeInterval(slot.duration / 2)
        return model.todayEntries.first { $0.start <= mid && mid < $0.end }
    }
}

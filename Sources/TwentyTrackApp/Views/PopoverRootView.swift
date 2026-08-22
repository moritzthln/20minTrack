import SwiftUI
import TwentyCore

/// Root of the popover: check-in or idle state, today's strip, footer.
/// A fresh hosting controller per open resets the local mode.
struct PopoverRootView: View {
    @ObservedObject var model: TrackerViewModel
    let onClosePopover: () -> Void
    let onOpenStats: () -> Void
    let onOpenSettings: () -> Void

    private enum Mode: Equatable {
        case auto
        case edit(slot: DateInterval, existing: Entry?)
    }

    @State private var mode: Mode = .auto
    @State private var fazitDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            todaySection
            fazitSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 540)
    }

    /// Always-visible daily notes, saved live on every keystroke.
    private var fazitSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tagesfazit / Notizen")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $fazitDraft)
                .font(.callout)
                .frame(height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .onChange(of: fazitDraft) { model.saveFazitLive($0) }
        }
        .onAppear { fazitDraft = model.todayFazit }
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
                    todayLine: model.todaySummaryLine,
                    lastText: model.lastEntryText,
                    preselectedLabelID: model.suggestedLabelID(for: pending)
                        ?? model.preferences.lastLabelID,
                    usageFor: { model.usageTotals(in: $0) },
                    onSave: { from, to, labelID, secondLabelID, text in
                        model.saveCheckin(
                            from: from, to: to, labelID: labelID,
                            secondLabelID: secondLabelID, text: text
                        )
                    },
                    onPostpone: onClosePopover
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
                preselectedLabelID: model.preferences.lastLabelID,
                usageFor: { model.usageTotals(in: $0) },
                onSave: { start, end, labelID, secondLabelID, text in
                    model.replaceEntry(
                        originalID: existing?.id, day: slot.start,
                        start: start, end: end, labelID: labelID,
                        secondLabelID: secondLabelID, text: text
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
                onSelect: handleSelect
            )
        }
    }

    /// Click = one slot (empty ones expand to the whole gap); drag = the
    /// exact dragged span as a fresh entry over whatever lies beneath.
    private func handleSelect(_ interval: DateInterval) {
        let blocks = SlotGrid.blockCount(
            start: interval.start, end: interval.end, calendar: model.calendar
        )
        if blocks <= 1 {
            mode = .edit(slot: expandedSlot(interval), existing: entry(at: interval))
        } else {
            mode = .edit(slot: interval, existing: nil)
        }
    }

    /// A tapped empty slot expands to the whole surrounding untracked gap
    /// (capped at the running block today) — one edit backfills it all.
    private func expandedSlot(_ slot: DateInterval) -> DateInterval {
        guard entry(at: slot) == nil else { return slot }
        let calendar = model.calendar
        let dayStart = calendar.startOfDay(for: Date())
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return slot }
        let blocked = model.todayEntries.map { DateInterval(start: $0.start, end: $0.end) }
        let mid = slot.start.addingTimeInterval(slot.duration / 2)
        guard var gap = GapFill.gaps(in: DateInterval(start: dayStart, end: dayEnd), blocked: blocked)
            .first(where: { $0.start <= mid && mid < $0.end }) else { return slot }
        let cap = max(slot.end, SlotGrid.floorBoundary(Date(), calendar: calendar))
        if gap.end > cap {
            gap = DateInterval(start: gap.start, end: cap)
        }
        return gap.duration > 0 ? gap : slot
    }

    private var footer: some View {
        HStack(spacing: 14) {
            footerButton("chart.bar", help: "Statistik", action: onOpenStats)
            muteMenu
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

    /// Timed mute: silence always comes with an expiry — never forever.
    private var muteMenu: some View {
        let isMuted = model.mutedUntil.map { $0 > Date() } ?? false
        return Menu {
            if let until = model.mutedUntil, isMuted {
                Text("Stumm bis \(muteUntilText(until))")
                Button("Wieder aktivieren") { model.unmute() }
            } else {
                Button("20 Minuten") { model.mute(for: 20 * 60) }
                Button("1 Stunde") { model.mute(for: 3600) }
                Button("2 Stunden") { model.mute(for: 2 * 3600) }
                Button("Bis morgen") { model.muteUntilTomorrow() }
            }
        } label: {
            Image(systemName: isMuted ? "bell.slash.fill" : "bell")
                .foregroundStyle(isMuted ? Color.orange : Color.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(isMuted
            ? "Stumm — läuft automatisch ab"
            : "Meldungen pausieren (z. B. für Calls) — Tracking läuft weiter")
    }

    private func muteUntilText(_ until: Date) -> String {
        let calendar = model.calendar
        if calendar.isDate(until, inSameDayAs: Date()) {
            return TimeFormatting.clock(until, calendar: calendar)
        }
        return "morgen"
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

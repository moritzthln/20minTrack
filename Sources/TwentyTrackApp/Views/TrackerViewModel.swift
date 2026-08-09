import Foundation
import SwiftUI
import TwentyCore

/// Observable state over Preferences + DayStore for the popover views.
/// All writes go through here so the status item can refresh afterwards.
final class TrackerViewModel: ObservableObject {
    let preferences: Preferences
    let dayStore: DayStore
    let calendar: Calendar

    @Published private(set) var pending: DateInterval?
    @Published private(set) var todayEntries: [Entry] = []
    @Published private(set) var activeLabels: [TrackLabel] = []
    @Published private(set) var labelsByID: [String: TrackLabel] = [:]
    @Published private(set) var todayFazit: String = ""

    /// Called after every data change — the status bar hooks its refresh here.
    var onDataChanged: (() -> Void)?

    init(preferences: Preferences, dayStore: DayStore, calendar: Calendar) {
        self.preferences = preferences
        self.dayStore = dayStore
        self.calendar = calendar
        ensureAnchor()
        reload()
    }

    /// First launch: settled time starts at the current block — no giant
    /// pending range out of nowhere.
    private func ensureAnchor(now: Date = Date()) {
        if preferences.checkinAnchor == nil {
            preferences.checkinAnchor = SlotGrid.floorBoundary(now, calendar: calendar)
        }
    }

    func reload(now: Date = Date()) {
        ensureAnchor(now: now)
        if let range = CheckinRules.pendingRange(
            anchor: preferences.checkinAnchor, now: now, calendar: calendar
        ) {
            pending = DateInterval(start: range.start, end: range.end)
        } else {
            pending = nil
        }
        todayEntries = dayStore.entries(onDay: now)
        let all = preferences.labels
        activeLabels = all.filter { !$0.archived }
        labelsByID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        todayFazit = dayStore.fazit(onDay: now) ?? ""
    }

    // MARK: - Check-in

    /// Fills only the untracked gaps of [from, pending.end) — manual strip
    /// edits inside the window survive — then settles the whole window.
    func saveCheckin(from: Date, labelID: String, text: String) {
        guard let pending else { return }
        let start = max(from, pending.start)
        let range = DateInterval(start: start, end: pending.end)
        let blocked = entriesAround(range).map { DateInterval(start: $0.start, end: $0.end) }
        for gap in GapFill.gaps(in: range, blocked: blocked) {
            dayStore.insert(
                start: gap.start, end: gap.end,
                labelID: labelID, text: text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        preferences.checkinAnchor = pending.end
        finishChange()
    }

    func skipCheckin() {
        guard let pending else { return }
        preferences.checkinAnchor = pending.end
        finishChange()
    }

    /// The pending window spans at most yesterday + today (lookback cap).
    private func entriesAround(_ range: DateInterval) -> [Entry] {
        var result = dayStore.entries(onDay: range.start)
        if !calendar.isDate(range.start, inSameDayAs: range.end) {
            result += dayStore.entries(onDay: range.end)
        }
        return result
    }

    // MARK: - Manual edits

    func replaceEntry(
        originalID: UUID?, day: Date,
        start: Date, end: Date, labelID: String, text: String
    ) {
        if let originalID {
            dayStore.remove(id: originalID, onDay: day)
        }
        dayStore.insert(
            start: start, end: end, labelID: labelID,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        finishChange()
    }

    func deleteEntry(id: UUID, day: Date) {
        dayStore.remove(id: id, onDay: day)
        finishChange()
    }

    func setTodayFazit(_ text: String) {
        dayStore.setFazit(text, onDay: Date())
        finishChange()
    }

    func togglePause() {
        preferences.trackingPaused.toggle()
        finishChange()
    }

    private func finishChange() {
        reload()
        onDataChanged?()
    }
}

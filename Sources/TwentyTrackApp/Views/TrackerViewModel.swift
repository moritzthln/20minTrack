import Foundation
import SwiftUI
import TwentyCore

/// Observable state over Preferences + DayStore (+ AppUsageStore) for the
/// popover views. All writes go through here so the status item can
/// refresh afterwards.
final class TrackerViewModel: ObservableObject {
    let preferences: Preferences
    let dayStore: DayStore
    let usageStore: AppUsageStore
    let calendar: Calendar

    @Published private(set) var pending: DateInterval?
    @Published private(set) var todayEntries: [Entry] = []
    @Published private(set) var activeLabels: [TrackLabel] = []
    @Published private(set) var labelsByID: [String: TrackLabel] = [:]
    @Published private(set) var todayFazit: String = ""

    /// Called after every data change — the status bar hooks its refresh here.
    var onDataChanged: (() -> Void)?
    /// Writes the recorder's open segment before usage queries.
    var flushUsage: (() -> Void)?

    init(
        preferences: Preferences, dayStore: DayStore,
        usageStore: AppUsageStore, calendar: Calendar
    ) {
        self.preferences = preferences
        self.dayStore = dayStore
        self.usageStore = usageStore
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
        normalizeAnchor(now: now)
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
        labelsByID = Dictionary(
            all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        todayFazit = dayStore.fazit(onDay: now) ?? ""
    }

    /// Clamps a future anchor (clock set back) and advances it over blocks
    /// that manual edits already covered — backfilled time never re-prompts.
    private func normalizeAnchor(now: Date) {
        guard let anchor = preferences.checkinAnchor else { return }
        let floorNow = SlotGrid.floorBoundary(now, calendar: calendar)
        let todayStart = calendar.startOfDay(for: now)
        let lookbackFloor = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        var adjusted = max(min(anchor, floorNow), min(lookbackFloor, floorNow))
        adjusted = AnchorAdvance.advanced(
            from: adjusted, upTo: floorNow,
            entries: entriesYesterdayAndToday(now: now), calendar: calendar
        )
        if adjusted != anchor {
            preferences.checkinAnchor = adjusted
        }
    }

    private func entriesYesterdayAndToday(now: Date) -> [Entry] {
        var result = dayStore.entries(onDay: now)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            result += dayStore.entries(onDay: yesterday)
        }
        return result
    }

    // MARK: - App usage

    /// Per-app time within `range` (memory aid line for the check-in and
    /// the slot editor).
    func usageTotals(in range: DateInterval) -> [AppUsageTotal] {
        flushUsage?()
        return usageStore.totals(in: range)
    }

    // MARK: - Check-in

    /// Fills only the untracked gaps of [from, pending.end) — manual strip
    /// edits inside the window survive — then settles the whole window.
    func saveCheckin(from: Date, labelID: String, text: String) {
        guard let pending else { return }
        let start = min(max(from, pending.start), pending.end)
        guard start < pending.end else { return }
        let range = DateInterval(start: start, end: pending.end)
        let blocked = entriesAround(range).map { DateInterval(start: $0.start, end: $0.end) }
        for gap in GapFill.gaps(in: range, blocked: blocked) {
            dayStore.insert(
                start: gap.start, end: gap.end,
                labelID: labelID, text: text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        preferences.checkinAnchor = pending.end
        preferences.lastLabelID = labelID
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
        preferences.lastLabelID = labelID
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
        NotificationCenter.default.post(name: .trackerSettingsChanged, object: nil)
        finishChange()
    }

    private func finishChange() {
        reload()
        onDataChanged?()
    }
}

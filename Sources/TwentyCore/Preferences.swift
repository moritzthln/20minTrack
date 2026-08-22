import Foundation

/// UserDefaults-backed settings (production domain
/// `com.moritzthelen.twentymintrack` via the app bundle id).
public final class Preferences {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key: String {
        case labels
        case checkinAnchor
        case lastLabelID
        case chimeVolume
        case autoOpenPopover
        case trackingPaused
        case mutedUntil
        case suppressDuringFocus
        case fazitPromptEnabled
        case fazitPromptMinute
        case absences
    }

    // MARK: - Labels

    /// Never-set (or undecodable) → the six seeded defaults. A written
    /// list — including a shorter one — persists as written.
    public var labels: [TrackLabel] {
        get {
            guard let data = defaults.data(forKey: Key.labels.rawValue),
                  let stored = try? JSONDecoder().decode([TrackLabel].self, from: data) else {
                return TrackLabel.defaults()
            }
            return stored
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.labels.rawValue)
        }
    }

    public var activeLabels: [TrackLabel] {
        labels.filter { !$0.archived }
    }

    /// Trims the name; empty names are rejected. Returns the stored label.
    @discardableResult
    public func addLabel(name: String, colorKey: String) -> TrackLabel? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let label = TrackLabel(id: UUID().uuidString, name: trimmed, colorKey: colorKey)
        labels = labels + [label]
        return label
    }

    /// Replaces the stored label with the same id; unknown ids are ignored.
    /// An empty (whitespace-only) name never persists — the old name stays.
    public func updateLabel(_ label: TrackLabel) {
        var sanitized = label
        sanitized.name = label.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.name.isEmpty else { return }
        labels = labels.map { $0.id == sanitized.id ? sanitized : $0 }
    }

    public func archiveLabel(id: String) {
        labels = labels.map { stored in
            guard stored.id == id else { return stored }
            var archived = stored
            archived.archived = true
            return archived
        }
    }

    public func label(byID id: String) -> TrackLabel? {
        labels.first { $0.id == id }
    }

    // MARK: - Check-in

    /// End of settled time — everything before it was logged or skipped.
    public var checkinAnchor: Date? {
        get { defaults.object(forKey: Key.checkinAnchor.rawValue) as? Date }
        set { defaults.set(newValue, forKey: Key.checkinAnchor.rawValue) }
    }

    /// The most recently saved label — preselected in the next check-in
    /// so the common "same activity continues" case is a single Return.
    public var lastLabelID: String? {
        get { defaults.string(forKey: Key.lastLabelID.rawValue) }
        set { defaults.set(newValue, forKey: Key.lastLabelID.rawValue) }
    }

    public var chimeVolume: Double {
        get {
            guard defaults.object(forKey: Key.chimeVolume.rawValue) != nil else { return 0.5 }
            return min(1, max(0, defaults.double(forKey: Key.chimeVolume.rawValue)))
        }
        set { defaults.set(min(1, max(0, newValue)), forKey: Key.chimeVolume.rawValue) }
    }

    public var autoOpenPopover: Bool {
        get {
            guard defaults.object(forKey: Key.autoOpenPopover.rawValue) != nil else { return true }
            return defaults.bool(forKey: Key.autoOpenPopover.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.autoOpenPopover.rawValue) }
    }

    public var trackingPaused: Bool {
        get { defaults.bool(forKey: Key.trackingPaused.rawValue) }
        set { defaults.set(newValue, forKey: Key.trackingPaused.rawValue) }
    }

    /// Manual "in a call" switch with an expiry: prompts and chimes stay
    /// silent until this moment, then come back on their own — never
    /// silent forever. nil = not muted.
    public var mutedUntil: Date? {
        get { defaults.object(forKey: Key.mutedUntil.rawValue) as? Date }
        set { defaults.set(newValue, forKey: Key.mutedUntil.rawValue) }
    }

    public func isMuted(now: Date = Date()) -> Bool {
        (mutedUntil ?? .distantPast) > now
    }

    /// Evening Fazit reminder (default on, 21:30). The minute is clamped
    /// to a sane evening range.
    public var fazitPromptEnabled: Bool {
        get {
            guard defaults.object(forKey: Key.fazitPromptEnabled.rawValue) != nil else { return true }
            return defaults.bool(forKey: Key.fazitPromptEnabled.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.fazitPromptEnabled.rawValue) }
    }

    /// Minute of day for the Fazit prompt, default 21:30 (1290).
    public var fazitPromptMinute: Int {
        get {
            guard defaults.object(forKey: Key.fazitPromptMinute.rawValue) != nil else { return 1290 }
            return min(max(defaults.integer(forKey: Key.fazitPromptMinute.rawValue), 0), 1439)
        }
        set { defaults.set(min(max(newValue, 0), 1439), forKey: Key.fazitPromptMinute.rawValue) }
    }

    /// Planned away periods, sorted by start. Never-set → empty.
    public var absences: [Absence] {
        get {
            guard let data = defaults.data(forKey: Key.absences.rawValue),
                  let stored = try? JSONDecoder().decode([Absence].self, from: data) else {
                return []
            }
            return stored
        }
        set {
            let sorted = newValue.sorted { $0.startDay < $1.startDay }
            guard let data = try? JSONEncoder().encode(sorted) else { return }
            defaults.set(data, forKey: Key.absences.rawValue)
        }
    }

    /// Start/end swapped if needed; whole-day semantics live in the rules.
    @discardableResult
    public func addAbsence(name: String, startDay: Date, endDay: Date) -> Absence {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let absence = Absence(
            name: trimmed.isEmpty ? "Abwesend" : trimmed,
            startDay: min(startDay, endDay),
            endDay: max(startDay, endDay)
        )
        absences = absences + [absence]
        return absence
    }

    public func removeAbsence(id: UUID) {
        absences = absences.filter { $0.id != id }
    }

    /// Suppress prompts while a macOS Focus mode is active (default on).
    public var suppressDuringFocus: Bool {
        get {
            guard defaults.object(forKey: Key.suppressDuringFocus.rawValue) != nil else { return true }
            return defaults.bool(forKey: Key.suppressDuringFocus.rawValue)
        }
        set { defaults.set(newValue, forKey: Key.suppressDuringFocus.rawValue) }
    }
}

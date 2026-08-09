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
        case chimeVolume
        case autoOpenPopover
        case trackingPaused
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
    public func updateLabel(_ label: TrackLabel) {
        labels = labels.map { $0.id == label.id ? label : $0 }
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
}

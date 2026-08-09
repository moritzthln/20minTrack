import Foundation

/// One span of an app being frontmost. Recorded locally as a memory aid
/// for the check-in ("Benutzt: Chrome 12 min …") — not an exact statistic.
public struct AppUsageSegment: Codable, Equatable, Identifiable {
    public let id: UUID
    public let bundleID: String
    public let name: String
    public let start: Date
    public let end: Date

    public init(id: UUID = UUID(), bundleID: String, name: String, start: Date, end: Date) {
        self.id = id
        self.bundleID = bundleID
        self.name = name
        self.start = start
        self.end = end
    }
}

/// Aggregated per-app time within a queried range.
public struct AppUsageTotal: Equatable {
    public let bundleID: String
    public let name: String
    public let seconds: TimeInterval

    public init(bundleID: String, name: String, seconds: TimeInterval) {
        self.bundleID = bundleID
        self.name = name
        self.seconds = seconds
    }
}

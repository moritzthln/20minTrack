import Foundation

/// Per-day JSON persistence for app usage segments (FocusLog pattern).
/// `upsert` is the heartbeat writer: insert-or-replace by segment id, split
/// at local midnight — every piece keeps the id (ids are unique per file,
/// so replace-by-id stays correct in each day file).
public final class AppUsageStore {
    private let directory: URL
    private let calendar: Calendar
    private let dayFormatter: DateFormatter

    public init(directory: URL, calendar: Calendar) {
        self.directory = directory
        self.calendar = calendar
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        self.dayFormatter = formatter
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Default production location: ~/Library/Application Support/20minTrack/usage
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("20minTrack/usage", isDirectory: true)
    }

    public func upsert(_ segment: AppUsageSegment) {
        guard segment.end > segment.start else { return }
        var cursor = segment.start
        while cursor < segment.end {
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let pieceEnd = min(segment.end, nextMidnight)
            upsertPiece(AppUsageSegment(
                id: segment.id, bundleID: segment.bundleID, name: segment.name,
                start: cursor, end: pieceEnd
            ))
            cursor = pieceEnd
        }
    }

    public func segments(onDay date: Date) -> [AppUsageSegment] {
        load(day: date).sorted { $0.start < $1.start }
    }

    // MARK: - Files

    private func upsertPiece(_ piece: AppUsageSegment) {
        var segments = load(day: piece.start)
        segments.removeAll { $0.id == piece.id }
        segments.append(piece)
        segments.sort { $0.start < $1.start }
        save(segments, day: piece.start)
    }

    private func fileURL(day: Date) -> URL {
        directory.appendingPathComponent(dayFormatter.string(from: day) + ".json")
    }

    private func load(day: Date) -> [AppUsageSegment] {
        guard let data = try? Data(contentsOf: fileURL(day: day)),
              let segments = try? JSONDecoder().decode([AppUsageSegment].self, from: data) else {
            return []
        }
        return segments
    }

    private func save(_ segments: [AppUsageSegment], day: Date) {
        guard let data = try? JSONEncoder().encode(segments) else { return }
        try? data.write(to: fileURL(day: day), options: .atomic)
    }
}

/// Pure aggregation for the usage line.
public enum AppUsageMath {
    /// Per-app seconds clipped to `range`, merged per bundle id (the most
    /// recently started segment names the app), sorted by time descending.
    public static func totals(
        segments: [AppUsageSegment], in range: DateInterval
    ) -> [AppUsageTotal] {
        var byBundle: [String: (name: String, seconds: TimeInterval, latestStart: Date)] = [:]
        for segment in segments {
            let overlapStart = max(segment.start, range.start)
            let overlapEnd = min(segment.end, range.end)
            guard overlapEnd > overlapStart else { continue }
            let seconds = overlapEnd.timeIntervalSince(overlapStart)
            if var existing = byBundle[segment.bundleID] {
                existing.seconds += seconds
                if segment.start >= existing.latestStart {
                    existing.name = segment.name
                    existing.latestStart = segment.start
                }
                byBundle[segment.bundleID] = existing
            } else {
                byBundle[segment.bundleID] = (segment.name, seconds, segment.start)
            }
        }
        return byBundle
            .map { AppUsageTotal(bundleID: $0.key, name: $0.value.name, seconds: $0.value.seconds) }
            .sorted { $0.seconds == $1.seconds ? $0.name < $1.name : $0.seconds > $1.seconds }
    }
}

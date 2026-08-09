import Foundation

/// Per-day JSON persistence for entries and the daily Fazit. One file per
/// local day (FocusLog pattern from the Timer app). Inserts split at local
/// midnight and trim any overlapped existing entries — last write wins,
/// which is the single rule behind editing, relabeling, and corrections.
public final class DayStore {
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

    /// Default production location: ~/Library/Application Support/20minTrack/days
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("20minTrack/days", isDirectory: true)
    }

    // MARK: - Entries

    /// Writes one logged span, split at local midnights. Spans with
    /// `end <= start` are discarded.
    public func insert(start: Date, end: Date, labelID: String, text: String) {
        guard end > start else { return }
        var cursor = start
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let pieceEnd = min(end, nextMidnight)
            insertPiece(start: cursor, end: pieceEnd, labelID: labelID, text: text)
            cursor = pieceEnd
        }
    }

    public func entries(onDay date: Date) -> [Entry] {
        load(day: date).entries.sorted { $0.start < $1.start }
    }

    public func remove(id: UUID, onDay date: Date) {
        var file = load(day: date)
        file.entries.removeAll { $0.id == id }
        save(file, day: date)
    }

    // MARK: - Fazit

    public func fazit(onDay date: Date) -> String? {
        load(day: date).fazit
    }

    /// Empty or whitespace-only text clears the Fazit.
    public func setFazit(_ text: String?, onDay date: Date) {
        var file = load(day: date)
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        file.fazit = (trimmed?.isEmpty ?? true) ? nil : trimmed
        save(file, day: date)
    }

    // MARK: - Insert internals

    private func insertPiece(start: Date, end: Date, labelID: String, text: String) {
        var file = load(day: start)
        file.entries = trimmed(file.entries, aroundStart: start, end: end)
        file.entries.append(Entry(start: start, end: end, labelID: labelID, text: text))
        file.entries.sort { $0.start < $1.start }
        save(file, day: start)
    }

    /// Removes the span `[s, e)` from every existing entry: untouched
    /// entries stay, partially covered ones are trimmed, an entry spanning
    /// both sides is split (the right part gets a fresh id), fully covered
    /// ones are dropped.
    private func trimmed(_ entries: [Entry], aroundStart s: Date, end e: Date) -> [Entry] {
        var result: [Entry] = []
        for x in entries {
            if x.end <= s || x.start >= e {
                result.append(x)
                continue
            }
            let keepsLeft = x.start < s
            if keepsLeft {
                result.append(Entry(id: x.id, start: x.start, end: s, labelID: x.labelID, text: x.text))
            }
            if x.end > e {
                result.append(Entry(
                    id: keepsLeft ? UUID() : x.id,
                    start: e, end: x.end, labelID: x.labelID, text: x.text
                ))
            }
        }
        return result
    }

    // MARK: - Files

    private func fileURL(day: Date) -> URL {
        directory.appendingPathComponent(dayFormatter.string(from: day) + ".json")
    }

    private func load(day: Date) -> DayFile {
        guard let data = try? Data(contentsOf: fileURL(day: day)),
              let file = try? JSONDecoder().decode(DayFile.self, from: data) else {
            return .empty
        }
        return file
    }

    private func save(_ file: DayFile, day: Date) {
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: fileURL(day: day), options: .atomic)
    }
}

import AppKit
import EventKit
import TwentyCore

/// Read-only access to the user's calendars (EventKit, local — no
/// network). Used only when calendar hints are enabled in Settings.
final class CalendarReader {
    static let shared = CalendarReader()

    private let store = EKEventStore()

    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    var isDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted
    }

    /// Asks macOS for calendar access (one system prompt); completion on main.
    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        let finish: (Bool, Error?) -> Void = { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: finish)
        } else {
            store.requestAccess(to: .event, completion: finish)
        }
    }

    struct CalendarChoice: Identifiable {
        let id: String
        let title: String
        let color: NSColor
    }

    func calendars() -> [CalendarChoice] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event)
            .map { CalendarChoice(id: $0.calendarIdentifier, title: $0.title, color: $0.color) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Events overlapping `range` — empty unless authorized.
    func events(in range: DateInterval) -> [CalendarEventInfo] {
        guard isAuthorized else { return [] }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarEventInfo(
                title: event.title ?? "",
                start: event.startDate, end: event.endDate,
                isAllDay: event.isAllDay, calendarID: event.calendar.calendarIdentifier
            )
        }
    }
}

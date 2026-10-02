import AppKit
import SwiftUI
import TwentyCore

/// Settings → Calendar: opt-in calendar hints in the check-in, which
/// calendars to read, and a way out when macOS access was denied.
struct CalendarSettingsSection: View {
    let preferences: Preferences

    @State private var enabled = false
    @State private var authorized = false
    @State private var denied = false
    @State private var calendars: [CalendarReader.CalendarChoice] = []
    @State private var selected: Set<String> = []

    private let reader = CalendarReader.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc("Kalender", "Calendar")).font(.headline)
            Toggle(
                loc("Termine im Check-in zeigen", "Show calendar events in the check-in"),
                isOn: Binding(get: { enabled }, set: setEnabled)
            )
            if enabled, denied {
                deniedHint
            } else if enabled, authorized {
                calendarList
            }
            Text(loc(
                "Nur lesend, lokal auf deinem Mac. Termine sind eine Erinnerung — Einträge werden nie automatisch erstellt.",
                "Read-only and local to your Mac. Events are a reminder — entries are never created automatically."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear(perform: load)
    }

    private var calendarList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(calendars) { choice in
                Toggle(isOn: Binding(
                    get: { selected.contains(choice.id) },
                    set: { toggle(choice.id, on: $0) }
                )) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(nsColor: choice.color)).frame(width: 8, height: 8)
                        Text(choice.title)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
        .padding(.leading, 20)
    }

    private var deniedHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc(
                "Kein Zugriff auf den Kalender. Erlaube ihn in den Systemeinstellungen.",
                "No calendar access. Allow it in System Settings."
            ))
            .font(.caption)
            .foregroundStyle(.orange)
            Button(loc("Systemeinstellungen öffnen", "Open System Settings")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(.leading, 20)
    }

    private func load() {
        enabled = preferences.calendarHintsEnabled
        refreshAccess()
    }

    private func refreshAccess() {
        authorized = reader.isAuthorized
        denied = reader.isDenied
        calendars = reader.calendars()
        let stored = Set(preferences.calendarIDs)
        // Empty stored set = all calendars.
        selected = stored.isEmpty ? Set(calendars.map(\.id)) : stored
    }

    private func setEnabled(_ value: Bool) {
        enabled = value
        preferences.calendarHintsEnabled = value
        guard value, !reader.isAuthorized, !reader.isDenied else {
            refreshAccess()
            return
        }
        reader.requestAccess { _ in refreshAccess() }
    }

    private func toggle(_ id: String, on: Bool) {
        var next = selected
        if on { next.insert(id) } else { next.remove(id) }
        guard !next.isEmpty else { return }  // at least one calendar
        selected = next
        let all = Set(calendars.map(\.id))
        preferences.calendarIDs = next == all ? [] : next.sorted()
    }
}

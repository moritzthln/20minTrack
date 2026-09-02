import AppKit
import SwiftUI
import TwentyCore

/// Evening reminder: a centered floating window with today's balance,
/// the day strip, and the Fazit editor. Same window mechanics as the
/// check-in window. Also hosts the morning catch-up for yesterday's
/// missed Fazit (one shared window, content swapped per show).
final class FazitWindowController {
    private var window: NSWindow?
    private let viewModel: TrackerViewModel

    init(viewModel: TrackerViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        present(
            title: loc("Tagesfazit", "Daily review"),
            rootView: AnyView(FazitWindowRootView(
                model: viewModel,
                onDone: { [weak self] in self?.window?.orderOut(nil) }
            ))
        )
    }

    /// Morning catch-up: the Fazit editor for a past day (yesterday).
    func show(catchupFor day: Date) {
        let store = viewModel.dayStore
        present(
            title: loc("Tagesfazit von gestern", "Yesterday's review"),
            rootView: AnyView(FazitCatchupRootView(
                day: day,
                entries: store.entries(onDay: day),
                labelsByID: viewModel.labelsByID,
                calendar: viewModel.calendar,
                initial: store.fazit(onDay: day) ?? "",
                onSave: { text in store.setFazit(text, onDay: day) },
                onDone: { [weak self] in self?.window?.orderOut(nil) }
            ))
        )
    }

    private func present(title: String, rootView: AnyView) {
        let window = ensureWindow()
        window.title = title
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }
        let created = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        created.isReleasedWhenClosed = false
        created.level = .floating
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window = created
        return created
    }
}

struct FazitWindowRootView: View {
    @ObservedObject var model: TrackerViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let line = model.todaySummaryLine {
                Text(loc("Heute: ", "Today: ") + line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            DayStripView(
                day: Date(),
                entries: model.todayEntries,
                labelsByID: model.labelsByID,
                calendar: model.calendar,
                now: Date(),
                height: 16
            )
            FazitView(
                initial: model.todayFazit,
                onSave: { text in
                    model.setTodayFazit(text)
                    onDone()
                },
                onCancel: onDone
            )
        }
        .padding(20)
        .frame(width: 560)
    }
}

/// Static variant for a past day: strip + editor, saved to that day.
struct FazitCatchupRootView: View {
    let day: Date
    let entries: [Entry]
    let labelsByID: [String: TrackLabel]
    let calendar: Calendar
    let initial: String
    let onSave: (String) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc(
                "Gestern (\(dayName)) blieb ohne Fazit — wie war der Tag?",
                "Yesterday (\(dayName)) has no review yet — how was it?"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            DayStripView(
                day: day,
                entries: entries,
                labelsByID: labelsByID,
                calendar: calendar,
                now: Date(),
                height: 16
            )
            FazitView(
                initial: initial,
                onSave: { text in
                    onSave(text)
                    onDone()
                },
                onCancel: onDone
            )
        }
        .padding(20)
        .frame(width: 560)
    }

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = l10nLocale
        formatter.calendar = calendar
        formatter.dateFormat = loc("EEE, d. MMMM", "EEE, MMMM d")
        return formatter.string(from: day)
    }
}

import AppKit
import SwiftUI
import TwentyCore

/// Evening reminder: a centered floating window with today's balance,
/// the day strip, and the Fazit editor. Same window mechanics as the
/// check-in window.
final class FazitWindowController {
    private var window: NSWindow?
    private let viewModel: TrackerViewModel

    init(viewModel: TrackerViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let window = ensureWindow()
        window.contentView = NSHostingView(rootView: FazitWindowRootView(
            model: viewModel,
            onDone: { [weak self] in self?.window?.orderOut(nil) }
        ))
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
        created.title = loc("Tagesfazit", "Daily review")
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

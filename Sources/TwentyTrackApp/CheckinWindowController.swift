import AppKit
import SwiftUI
import TwentyCore

/// The "you cannot miss it" prompt: a floating window popping up centered
/// on screen at every boundary (all Spaces, above fullscreen apps),
/// carrying the full check-in form — Return saves, Esc postpones. It
/// closes on save/postpone and whenever nothing is pending anymore.
final class CheckinWindowController {
    private var window: NSWindow?
    private let viewModel: TrackerViewModel

    init(viewModel: TrackerViewModel) {
        self.viewModel = viewModel
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func show() {
        let window = ensureWindow()
        window.contentView = NSHostingView(rootView: CheckinWindowRootView(
            model: viewModel,
            onDone: { [weak self] in self?.close() }
        ))
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }
        let created = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        created.title = "Check-in"
        created.isReleasedWhenClosed = false
        created.level = .floating
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window = created
        return created
    }
}

/// Window content: the shared check-in form, or a brief all-done state
/// when the pending span vanished while the window was open.
struct CheckinWindowRootView: View {
    @ObservedObject var model: TrackerViewModel
    let onDone: () -> Void

    var body: some View {
        Group {
            if let pending = model.pending {
                CheckinView(
                    pending: pending,
                    labels: model.activeLabels,
                    calendar: model.calendar,
                    todayLine: model.todaySummaryLine,
                    lastText: model.lastEntryText,
                    preselectedLabelID: model.suggestedLabelID(for: pending)
                        ?? model.preferences.lastLabelID,
                    usageFor: { model.usageTotals(in: $0) },
                    onSave: { from, labelID, text in
                        model.saveCheckin(from: from, labelID: labelID, text: text)
                        onDone()
                    },
                    onPostpone: onDone
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Color.green)
                    Text("Alles erfasst")
                        .font(.headline)
                    Spacer()
                    Button("Schließen", action: onDone)
                        .buttonStyle(PillButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}

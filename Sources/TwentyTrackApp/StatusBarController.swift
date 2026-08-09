import AppKit
import SwiftUI
import TwentyCore

extension Notification.Name {
    /// Posted by settings when a preference changed that the status item
    /// or scheduler cares about (pause, …).
    static let trackerSettingsChanged = Notification.Name("trackerSettingsChanged")
}

/// Owns the status item, the popover, and the check-in loop.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let preferences: Preferences
    private let calendar: Calendar
    private let viewModel: TrackerViewModel
    private let scheduler: BoundaryScheduler
    private let usageTracker: AppUsageTracker
    private let statsController: StatsWindowController
    private let settingsController: SettingsWindowController

    private var titleRefreshTimer: Foundation.Timer?
    private var settingsObserver: NSObjectProtocol?
    /// The pending end we last chimed for — one prompt per block, even
    /// when wake events re-fire the boundary hook.
    private var lastPromptedEnd: Date?

    init(
        preferences: Preferences, dayStore: DayStore,
        usageStore: AppUsageStore, usageTracker: AppUsageTracker, calendar: Calendar
    ) {
        self.preferences = preferences
        self.calendar = calendar
        self.usageTracker = usageTracker
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.viewModel = TrackerViewModel(
            preferences: preferences, dayStore: dayStore,
            usageStore: usageStore, calendar: calendar
        )
        self.scheduler = BoundaryScheduler(calendar: calendar)
        self.statsController = StatsWindowController(
            dayStore: dayStore, preferences: preferences, calendar: calendar,
            usageFor: { [weak usageTracker] range in
                usageTracker?.flush()
                return usageStore.totals(in: range)
            }
        )
        self.settingsController = SettingsWindowController(preferences: preferences)
        super.init()

        viewModel.flushUsage = { [weak usageTracker] in usageTracker?.flush() }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }
        popover.behavior = .transient
        popover.animates = false

        viewModel.onDataChanged = { [weak self] in self?.refresh() }
        scheduler.onBoundary = { [weak self] in self?.boundaryFired() }
        scheduler.start()

        let timer = Foundation.Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        titleRefreshTimer = timer

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .trackerSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.viewModel.reload()
            self?.refresh()
        }

        refresh()

        // Login/relaunch has no wake event: prompt shortly after start when
        // something is already pending (e.g. last night's sleep).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.boundaryFired()
        }
    }

    deinit {
        titleRefreshTimer?.invalidate()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    /// Called from applicationWillTerminate: closes the open usage segment.
    func prepareForTermination() {
        usageTracker.prepareForTermination()
    }

    // MARK: - Check-in loop

    private func boundaryFired() {
        viewModel.reload()
        refresh()
        guard !preferences.trackingPaused,
              let pending = viewModel.pending,
              pending.end != lastPromptedEnd else { return }
        lastPromptedEnd = pending.end
        SoundPlayer.playChime(volume: preferences.chimeVolume)
        if preferences.autoOpenPopover, !popover.isShown {
            showPopover()
        }
    }

    // MARK: - Status item

    func refresh() {
        let now = Date()
        let pendingBlocks = viewModel.pending.map {
            SlotGrid.blockCount(start: $0.start, end: $0.end, calendar: calendar)
        } ?? 0
        let next = SlotGrid.nextBoundary(after: now, calendar: calendar)
        let minutes = max(1, Int(ceil(next.timeIntervalSince(now) / 60)))
        let presentation = MenuBarPresentation.make(
            paused: preferences.trackingPaused,
            pendingBlocks: pendingBlocks,
            minutesToNext: minutes
        )
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: "20minTrack"
        ) ?? NSImage(systemSymbolName: "clock", accessibilityDescription: "20minTrack")
        button.title = presentation.title.isEmpty ? "" : " " + presentation.title
    }

    @objc private func statusButtonClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "20minTrack beenden",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        guard let button = statusItem.button else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        viewModel.reload()
        // Fresh hosting controller per open: local view state (edit mode,
        // draft text) resets, stored values reload. Timer pattern.
        popover.contentViewController = NSHostingController(rootView: PopoverRootView(
            model: viewModel,
            onClosePopover: { [weak self] in
                self?.popover.performClose(nil)
            },
            onOpenStats: { [weak self] in
                self?.popover.performClose(nil)
                self?.statsController.show()
            },
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.settingsController.show()
            }
        ))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

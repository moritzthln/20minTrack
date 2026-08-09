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
    private let checkinWindowController: CheckinWindowController
    private let fazitWindowController: FazitWindowController
    /// The day the evening Fazit prompt already fired (or was settled).
    private var lastFazitPromptDay: Date?

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
        self.checkinWindowController = CheckinWindowController(viewModel: viewModel)
        self.fazitWindowController = FazitWindowController(viewModel: viewModel)
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

    /// Reads macOS Focus state from the DoNotDisturb assertions database.
    private func isSystemFocusActive() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
        guard let data = try? Data(contentsOf: url) else { return false }
        return FocusAssertions.isActive(json: data)
    }

    private func boundaryFired() {
        viewModel.reload()
        refresh()
        guard !preferences.trackingPaused,
              let pending = viewModel.pending,
              pending.end != lastPromptedEnd else { return }
        // Muted (call) or an active macOS Focus: stay silent, do NOT mark
        // as prompted — the next boundary after unmute/focus-end prompts.
        if preferences.muted { return }
        if preferences.suppressDuringFocus, isSystemFocusActive() { return }
        lastPromptedEnd = pending.end
        SoundPlayer.playChime(volume: preferences.chimeVolume)
        // Center-screen prompt — impossible to miss, all Spaces, above
        // fullscreen. Re-shown (and re-centered) even if already open so
        // it grabs attention again at every boundary.
        if preferences.autoOpenPopover {
            popover.performClose(nil)
            checkinWindowController.show()
        }
    }

    // MARK: - Status item

    func refresh() {
        let now = Date()
        if viewModel.pending == nil, checkinWindowController.isVisible {
            checkinWindowController.close()
        }
        checkFazitPrompt(now: now)
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

    /// Evening reminder: once per day after the configured time, only
    /// while today's Fazit is still empty; respects mute and Focus.
    private func checkFazitPrompt(now: Date) {
        guard preferences.fazitPromptEnabled,
              !preferences.trackingPaused,
              !preferences.muted else { return }
        let minute = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)
        guard minute >= preferences.fazitPromptMinute else { return }
        let today = calendar.startOfDay(for: now)
        guard lastFazitPromptDay != today else { return }
        guard viewModel.todayFazit.isEmpty else {
            lastFazitPromptDay = today
            return
        }
        if preferences.suppressDuringFocus, isSystemFocusActive() { return }
        lastFazitPromptDay = today
        SoundPlayer.playChime(volume: preferences.chimeVolume)
        fazitWindowController.show()
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
            keyEquivalent: ""
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
        // No makeKey() here: under the Xcode/macOS SDK build it detaches
        // the popover from the status item. The text field focuses itself
        // via @FocusState anyway.
        realignPopover(to: button)
    }

    /// The Xcode-SDK build places the popover ~2 cm below the status item.
    /// Generic correction: after showing, snap the popover window's top
    /// edge to the button's bottom edge (no-op when AppKit got it right).
    private func realignPopover(to button: NSStatusBarButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let popoverWindow = self.popover.contentViewController?.view.window,
                  let buttonWindow = button.window else { return }
            let anchorRect = buttonWindow.convertToScreen(
                button.convert(button.bounds, to: nil)
            )
            let delta = anchorRect.minY - popoverWindow.frame.maxY
            guard abs(delta) > 4 else { return }
            popoverWindow.setFrameOrigin(NSPoint(
                x: popoverWindow.frame.origin.x,
                y: popoverWindow.frame.origin.y + delta
            ))
        }
    }
}

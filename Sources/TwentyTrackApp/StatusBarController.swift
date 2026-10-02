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
    private let mainWindow: MainWindowController
    private let checkinWindowController: CheckinWindowController
    private let fazitWindowController: FazitWindowController
    /// The day the evening Fazit prompt already fired (or was settled).
    private var lastFazitPromptDay: Date?
    /// The day the morning catch-up already fired (or was settled).
    private var lastFazitCatchupDay: Date?

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
        self.mainWindow = MainWindowController(preferences: preferences) { [weak usageTracker] in
            StatsView(
                dayStore: dayStore, preferences: preferences, calendar: calendar,
                usageFor: { range in
                    usageTracker?.flush()
                    return usageStore.totals(in: range)
                }
            )
        }
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
        if let path = SnapshotMode.outputPath {
            presentSnapshots(to: path)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.boundaryFired()
        }
    }

    /// README screenshots (see SnapshotMode): off-screen copies of the
    /// popover, the statistics tabs, and the settings.
    private func presentSnapshots(to path: String) {
        viewModel.reload()
        let store = viewModel.dayStore
        func stats(_ tab: String) -> AnyView {
            AnyView(StatsView(
                dayStore: store, preferences: preferences, calendar: calendar,
                usageFor: { _ in [] }, initialTab: tab
            ))
        }
        let popoverView = AnyView(PopoverRootView(
            model: viewModel, onClosePopover: {}, onOpenStats: {}, onOpenSettings: {}
        ))
        SnapshotMode.present([
            .init(name: "checkin", title: loc("Check-in", "Check-in"), size: NSSize(width: 560, height: 0),
                  view: AnyView(CheckinWindowRootView(model: viewModel, onDone: {}))),
            .init(name: "popover", title: nil, size: NSSize(width: 540, height: 0), view: popoverView),
            .init(name: "stats-day", title: loc("Statistik", "Statistics"), size: NSSize(width: 520, height: 860), view: stats("day")),
            .init(name: "stats-week", title: loc("Statistik", "Statistics"), size: NSSize(width: 520, height: 860), view: stats("week")),
            .init(name: "stats-month", title: loc("Statistik", "Statistics"), size: NSSize(width: 520, height: 860), view: stats("month")),
            .init(name: "settings", title: loc("Einstellungen", "Settings"), size: NSSize(width: 520, height: 900),
                  view: AnyView(SettingsView(preferences: preferences))),
        ], to: path)
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
        if preferences.isMuted() { return }
        if AbsenceRules.isAbsent(day: Date(), in: preferences.absences, calendar: calendar) {
            return
        }
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
        checkFazitCatchup(now: now)
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
              !preferences.isMuted(now: now),
              !AbsenceRules.isAbsent(day: now, in: preferences.absences, calendar: calendar)
        else { return }
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

    /// Morning catch-up: yesterday ended without a Fazit → one extra
    /// prompt from 09:30 until the evening prompt takes over. Same
    /// gates and once-per-day marker pattern as the evening prompt.
    private func checkFazitCatchup(now: Date) {
        guard preferences.fazitPromptEnabled,
              !preferences.trackingPaused,
              !preferences.isMuted(now: now)
        else { return }
        let today = calendar.startOfDay(for: now)
        guard lastFazitCatchupDay != today else { return }
        // Cheap time-window gate first, so the day-store reads below
        // don't repeat on every 10 s tick outside the window.
        let minute = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)
        guard minute >= FazitCatchup.startMinute,
              minute < preferences.fazitPromptMinute
        else { return }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return
        }
        let hasFazit = !(viewModel.dayStore.fazit(onDay: yesterday) ?? "").isEmpty
        let hasEntries = !viewModel.dayStore.entries(onDay: yesterday).isEmpty
        guard let day = FazitCatchup.dueDay(
            now: now, calendar: calendar,
            yesterdayHasFazit: hasFazit, yesterdayHasEntries: hasEntries,
            eveningPromptMinute: preferences.fazitPromptMinute,
            absences: preferences.absences
        ) else {
            // Inside the window nil is final for today — settle.
            lastFazitCatchupDay = today
            return
        }
        if preferences.suppressDuringFocus, isSystemFocusActive() { return }
        lastFazitCatchupDay = today
        SoundPlayer.playChime(volume: preferences.chimeVolume)
        fazitWindowController.show(catchupFor: day)
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

    // MARK: - Navigation (also reached via the app menu shortcuts)

    func openStatistics() {
        popover.performClose(nil)
        mainWindow.show(.statistics)
    }

    func openSettings() {
        popover.performClose(nil)
        mainWindow.show(.settings)
    }

    func togglePause() {
        viewModel.togglePause()
        refresh()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        for (title, selector, key) in AppMenuActions.items(paused: preferences.trackingPaused) {
            menu.addItem(NSMenuItem(title: title, action: selector, keyEquivalent: key))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: loc("20minTrack beenden", "Quit 20minTrack"),
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
                self?.openStatistics()
            },
            onOpenSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.openSettings()
            }
        ))
        // Same call as the Timer app. Positioning misbehaves only when
        // built against the Xcode 26 SDK — build.sh pins the CLT
        // toolchain instead of papering over it here.
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

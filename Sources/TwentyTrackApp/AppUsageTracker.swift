import AppKit
import TwentyCore

/// Records which app is frontmost — the local memory aid behind the
/// "Benutzt: …" line. Segments close on app switch, sleep, and screen
/// lock; a 60 s heartbeat persists the open segment (crash loses ≤ 60 s).
/// No input-idle detection (v2 limitation, documented): an app left
/// frontmost counts until lock/sleep. The own app is never recorded.
/// `trackingPaused` pauses recording too.
final class AppUsageTracker {
    private let store: AppUsageStore
    private let preferences: Preferences
    private var current: (id: UUID, bundleID: String, name: String, start: Date)?
    private var heartbeat: Foundation.Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var settingsObserver: NSObjectProtocol?
    private let ownBundleID = Bundle.main.bundleIdentifier

    init(store: AppUsageStore, preferences: Preferences) {
        self.store = store
        self.preferences = preferences
        registerObservers()

        let timer = Foundation.Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.flush()
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        heartbeat = timer

        openFrontmost()
    }

    deinit {
        heartbeat?.invalidate()
        let workspace = NSWorkspace.shared.notificationCenter
        for token in workspaceObservers {
            workspace.removeObserver(token)
        }
        let distributed = DistributedNotificationCenter.default()
        for token in distributedObservers {
            distributed.removeObserver(token)
        }
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    /// Persists the open segment up to now (heartbeat + before usage reads).
    func flush(at date: Date = Date()) {
        guard let current else { return }
        store.upsert(AppUsageSegment(
            id: current.id, bundleID: current.bundleID, name: current.name,
            start: current.start, end: date
        ))
    }

    func prepareForTermination() {
        closeCurrent(at: Date())
    }

    // MARK: - Events

    private func registerObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.frontmostChanged(to: app)
        })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.closeCurrent(at: Date()) })
        workspaceObservers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.openFrontmost() })

        let distributed = DistributedNotificationCenter.default()
        distributedObservers.append(distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.closeCurrent(at: Date()) })
        distributedObservers.append(distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.openFrontmost() })

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .trackerSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.reconcilePause() }
    }

    private func frontmostChanged(to app: NSRunningApplication?) {
        let now = Date()
        closeCurrent(at: now)
        open(app, at: now)
    }

    private func openFrontmost() {
        open(NSWorkspace.shared.frontmostApplication, at: Date())
    }

    private func open(_ app: NSRunningApplication?, at date: Date) {
        if current != nil {
            closeCurrent(at: date)
        }
        guard !preferences.trackingPaused,
              let app, let bundleID = app.bundleIdentifier,
              bundleID != ownBundleID else { return }
        current = (UUID(), bundleID, app.localizedName ?? bundleID, date)
    }

    private func closeCurrent(at date: Date) {
        flush(at: date)
        current = nil
    }

    private func reconcilePause() {
        if preferences.trackingPaused {
            closeCurrent(at: Date())
        } else if current == nil {
            openFrontmost()
        }
    }
}

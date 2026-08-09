import AppKit
import TwentyCore

/// Records which app is frontmost — the local memory aid behind the
/// "In dieser Zeit benutzt" list. While a browser is frontmost the open
/// segment carries the active tab's domain instead of the browser
/// (`site:<domain>` / name = domain, re-checked every 10 s), so browser
/// time and site time never double-count. Segments close on app switch,
/// sleep, and screen lock; a 60 s heartbeat persists the open segment.
/// No input-idle detection (documented limitation). The own app is never
/// recorded; `trackingPaused` pauses recording.
final class AppUsageTracker {
    private let store: AppUsageStore
    private let preferences: Preferences
    private var current: (id: UUID, segmentBundleID: String, name: String, start: Date)?
    private var frontBundleID: String?
    private var heartbeat: Foundation.Timer?
    private var domainPoll: Foundation.Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var settingsObserver: NSObjectProtocol?
    private let ownBundleID = Bundle.main.bundleIdentifier

    init(store: AppUsageStore, preferences: Preferences) {
        self.store = store
        self.preferences = preferences
        registerObservers()

        let beat = Foundation.Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.flush()
        }
        beat.tolerance = 10
        RunLoop.main.add(beat, forMode: .common)
        heartbeat = beat

        let poll = Foundation.Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            self?.pollBrowserDomain()
        }
        poll.tolerance = 2
        RunLoop.main.add(poll, forMode: .common)
        domainPoll = poll

        openFrontmost()
    }

    deinit {
        heartbeat?.invalidate()
        domainPoll?.invalidate()
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
            id: current.id, bundleID: current.segmentBundleID, name: current.name,
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
        frontBundleID = app?.bundleIdentifier
        guard !preferences.trackingPaused,
              let app, let bundleID = app.bundleIdentifier,
              bundleID != ownBundleID else { return }
        let identity = segmentIdentity(bundleID: bundleID, appName: app.localizedName ?? bundleID)
        current = (UUID(), identity.bundleID, identity.name, date)
    }

    private func closeCurrent(at date: Date) {
        flush(at: date)
        current = nil
    }

    /// Browser frontmost with a readable tab → the segment is the domain.
    private func segmentIdentity(
        bundleID: String, appName: String
    ) -> (bundleID: String, name: String) {
        if BrowserScripting.isBrowser(bundleID),
           let domain = BrowserScripting.activeTabDomain(bundleID: bundleID) {
            return ("site:" + domain, domain)
        }
        return (bundleID, appName)
    }

    /// Re-checks the active tab while a browser stays frontmost; a domain
    /// change closes the segment and opens the next one.
    private func pollBrowserDomain() {
        guard !preferences.trackingPaused,
              let frontBundleID, BrowserScripting.isBrowser(frontBundleID),
              let openSegment = current else { return }
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? frontBundleID
        let identity = segmentIdentity(bundleID: frontBundleID, appName: appName)
        guard identity.bundleID != openSegment.segmentBundleID else { return }
        let now = Date()
        closeCurrent(at: now)
        current = (UUID(), identity.bundleID, identity.name, now)
    }

    private func reconcilePause() {
        if preferences.trackingPaused {
            closeCurrent(at: Date())
        } else if current == nil {
            openFrontmost()
        }
    }
}

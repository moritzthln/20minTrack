import AppKit
import TwentyCore

/// Fires `onBoundary` at every wall-clock 20-minute boundary while the app
/// runs, and once after wake / clock changes (the controller decides
/// whether anything is actually pending — missed boundaries collapse into
/// one pending range, so there is never a catch-up storm).
final class BoundaryScheduler {
    var onBoundary: (() -> Void)?

    private let calendar: Calendar
    private var timer: Foundation.Timer?
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    init(calendar: Calendar) {
        self.calendar = calendar
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append((workspace, workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.externalChange() }))
        let center = NotificationCenter.default
        observers.append((center, center.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.externalChange() }))
    }

    deinit {
        timer?.invalidate()
        for (center, token) in observers {
            center.removeObserver(token)
        }
    }

    func start() {
        scheduleNext()
    }

    private func scheduleNext() {
        timer?.invalidate()
        let next = SlotGrid.nextBoundary(after: Date(), calendar: calendar)
        let timer = Foundation.Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            self?.onBoundary?()
            self?.scheduleNext()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func externalChange() {
        scheduleNext()
        onBoundary?()
    }
}

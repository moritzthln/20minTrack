import Foundation

/// Pure mapping of tracker state to the status item's symbol and title.
public enum MenuBarPresentation {
    public static func make(
        paused: Bool, pendingBlocks: Int, minutesToNext: Int
    ) -> (symbolName: String, title: String) {
        if paused { return ("pause.circle", "") }
        if pendingBlocks > 0 { return ("20.circle.fill", "\(pendingBlocks)") }
        return ("20.circle", "\(minutesToNext) m")
    }
}

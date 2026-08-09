import Foundation

/// Pure mapping of tracker state to the status item — one compact number
/// circle, never a text title: outline circle = minutes until the next
/// check-in (counting down), filled circle = number of open blocks
/// waiting, pause icon while paused. SF Symbols ships number circles for
/// 0…50, so both values clamp into that range.
public enum MenuBarPresentation {
    public static func make(
        paused: Bool, pendingBlocks: Int, minutesToNext: Int
    ) -> (symbolName: String, title: String) {
        if paused { return ("pause.circle", "") }
        if pendingBlocks > 0 {
            return ("\(min(pendingBlocks, 50)).circle.fill", "")
        }
        return ("\(min(max(minutesToNext, 1), 20)).circle", "")
    }
}

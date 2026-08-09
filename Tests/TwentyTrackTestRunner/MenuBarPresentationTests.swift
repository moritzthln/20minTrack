import Foundation
import TwentyCore

func runMenuBarPresentationTests() {
    test("countdown renders as a bare number circle, no title") {
        let p = MenuBarPresentation.make(paused: false, pendingBlocks: 0, minutesToNext: 7)
        try expectEqual(p.symbolName, "7.circle")
        try expectEqual(p.title, "")
    }

    test("pending blocks render as a filled number circle") {
        let p = MenuBarPresentation.make(paused: false, pendingBlocks: 3, minutesToNext: 12)
        try expectEqual(p.symbolName, "3.circle.fill")
        try expectEqual(p.title, "")
    }

    test("paused wins over pending") {
        let p = MenuBarPresentation.make(paused: true, pendingBlocks: 3, minutesToNext: 12)
        try expectEqual(p.symbolName, "pause.circle")
        try expectEqual(p.title, "")
    }

    test("numbers clamp to the SF Symbols range") {
        try expectEqual(
            MenuBarPresentation.make(paused: false, pendingBlocks: 60, minutesToNext: 5).symbolName,
            "50.circle.fill"
        )
        try expectEqual(
            MenuBarPresentation.make(paused: false, pendingBlocks: 0, minutesToNext: 0).symbolName,
            "1.circle"
        )
        try expectEqual(
            MenuBarPresentation.make(paused: false, pendingBlocks: 0, minutesToNext: 25).symbolName,
            "20.circle"
        )
    }
}

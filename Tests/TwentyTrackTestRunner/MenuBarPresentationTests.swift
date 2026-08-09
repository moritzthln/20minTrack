import Foundation
import TwentyCore

func runMenuBarPresentationTests() {
    test("idle shows the grid symbol and minutes to the next check-in") {
        let p = MenuBarPresentation.make(paused: false, pendingBlocks: 0, minutesToNext: 7)
        try expectEqual(p.symbolName, "20.circle")
        try expectEqual(p.title, "7 m")
    }

    test("pending blocks show the filled symbol and the count") {
        let p = MenuBarPresentation.make(paused: false, pendingBlocks: 3, minutesToNext: 12)
        try expectEqual(p.symbolName, "20.circle.fill")
        try expectEqual(p.title, "3")
    }

    test("paused wins over pending") {
        let p = MenuBarPresentation.make(paused: true, pendingBlocks: 3, minutesToNext: 12)
        try expectEqual(p.symbolName, "pause.circle")
        try expectEqual(p.title, "")
    }
}

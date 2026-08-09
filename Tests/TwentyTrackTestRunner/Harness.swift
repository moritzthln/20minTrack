import Foundation

// Minimal test harness — XCTest is unavailable with Command Line Tools only.
// Ported from ~/AI/Tools/Timer.

var totalTests = 0
var failedTests = 0

func test(_ name: String, _ body: () throws -> Void) {
    totalTests += 1
    do {
        try body()
        print("PASS \(name)")
    } catch {
        failedTests += 1
        print("FAIL \(name): \(error)")
    }
}

struct AssertionError: Error, CustomStringConvertible {
    let description: String
}

func expect(
    _ condition: Bool, _ message: String,
    file: StaticString = #file, line: UInt = #line
) throws {
    if !condition {
        throw AssertionError(description: "\(message) [\(file):\(line)]")
    }
}

func expectEqual<T: Equatable>(
    _ actual: T, _ expected: T, _ context: String = "",
    file: StaticString = #file, line: UInt = #line
) throws {
    try expect(
        actual == expected,
        "\(context) expected \(expected), got \(actual)",
        file: file, line: line
    )
}

func expectEqual(
    _ actual: Double, _ expected: Double, accuracy: Double, _ context: String = "",
    file: StaticString = #file, line: UInt = #line
) throws {
    try expect(
        abs(actual - expected) <= accuracy,
        "\(context) expected \(expected) ± \(accuracy), got \(actual)",
        file: file, line: line
    )
}

func expectNil<T>(
    _ value: T?, _ context: String = "",
    file: StaticString = #file, line: UInt = #line
) throws {
    try expect(value == nil, "\(context) expected nil, got \(String(describing: value))",
               file: file, line: line)
}

/// Fixed calendar for deterministic tests (incl. DST assertions).
let testCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return cal
}()

func makeDate(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int, _ minute: Int, _ second: Int = 0
) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = second
    return testCalendar.date(from: comps)!
}

func finishTestRun() -> Never {
    print("---")
    print("\(totalTests) tests, \(failedTests) failures")
    exit(failedTests == 0 ? 0 : 1)
}

// swift-tools-version:5.9
import PackageDescription

// Note: no XCTest target — the machine builds with Command Line Tools only,
// which ship no XCTest.framework. Tests run via the TwentyTrackTestRunner
// executable instead: `swift run TwentyTrackTestRunner`.
let package = Package(
    name: "TwentyMinTrack",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "TwentyCore", path: "Sources/TwentyCore"),
        .executableTarget(
            name: "TwentyTrackApp",
            dependencies: ["TwentyCore"],
            path: "Sources/TwentyTrackApp"
        ),
        .executableTarget(
            name: "TwentyTrackTestRunner",
            dependencies: ["TwentyCore"],
            path: "Tests/TwentyTrackTestRunner"
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "kasane",
    platforms: [.macOS(.v15)],
    targets: [
        // Config, trigger recognition, and the ON/OFF state machine. No IOKit, so it is testable.
        .target(name: "KasaneCore"),
        .testTarget(name: "KasaneCoreTests", dependencies: ["KasaneCore"]),
    ]
)

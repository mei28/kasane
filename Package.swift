// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "kasane",
    platforms: [.macOS(.v15)],
    targets: [
        // Config, trigger recognition, and the ON/OFF state machine. No IOKit, so it is testable.
        .target(name: "KasaneCore"),
        .testTarget(name: "KasaneCoreTests", dependencies: ["KasaneCore"]),
        // The XPC protocol and signing checks shared by kasaned and the menu bar app.
        .target(name: "KasaneIPC"),
        // The root daemon: IOKit glue around KasaneCore, checked on the hardware.
        .executableTarget(name: "kasaned", dependencies: ["KasaneCore", "KasaneIPC"]),
        // The menu bar app. `just app` puts it and kasaned into Kasane.app.
        .executableTarget(name: "Kasane", dependencies: ["KasaneCore", "KasaneIPC"]),
    ]
)

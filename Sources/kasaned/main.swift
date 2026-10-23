import Foundation
import KasaneCore

guard CommandLine.arguments.count == 2 else {
    log("usage: kasaned <config.json>")
    exit(EX_USAGE)
}
let configPath = CommandLine.arguments[1]
let config: Config
do {
    config = try Config.parse(Data(contentsOf: URL(filePath: configPath)))
} catch {
    // Not starting means never seizing, so a bad config leaves the built-in keyboard usable.
    log("cannot use \(configPath): \(error)")
    exit(EXIT_FAILURE)
}

let daemon = Daemon(config: config)
do {
    try daemon.start()
} catch {
    log("\(error)")
    exit(EXIT_FAILURE)
}

// Ctrl-C in a terminal, or launchd stopping the daemon.
var signalSources: [any DispatchSourceSignal] = []
for signalNumber in [SIGINT, SIGTERM] {
    signal(signalNumber, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
    source.setEventHandler { MainActor.assumeIsolated { daemon.stop() } }
    source.resume()
    signalSources.append(source)
}

CFRunLoopRun()

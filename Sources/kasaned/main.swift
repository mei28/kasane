import Foundation
import KasaneIPC

// launchd starts kasaned from Kasane.app with no arguments; the config lives in ConfigStore.
guard CommandLine.arguments.count == 1 else {
    log("usage: kasaned (takes no arguments)")
    exit(EX_USAGE)
}

let clientRequirement: String
do {
    clientRequirement = try sameSignerRequirement()
} catch {
    // Unsigned, kasaned cannot tell its app from any other process, so it does not run at all.
    log("\(error); kasaned must be signed by `just app`")
    exit(EXIT_FAILURE)
}

let daemon = Daemon(store: ConfigStore(), watchdog: Watchdog())
do {
    try daemon.start(clientRequirement: clientRequirement)
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

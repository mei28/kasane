import IOKit

struct ConsoleState: Equatable {
    var onConsole: Bool
    var screenLocked: Bool
}

/// Reads IOConsoleUsers on the registry root. Unlike com.apple.screenIsLocked, a LaunchDaemon
/// sees it without a GUI session.
func readConsoleState(_ registryRoot: io_registry_entry_t) -> ConsoleState {
    // The property is absent while nobody is logged in.
    guard
        let property = IORegistryEntryCreateCFProperty(
            registryRoot, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    else {
        return ConsoleState(onConsole: false, screenLocked: false)
    }
    guard let users = property as? [[String: Any]] else {
        fatalError("IOConsoleUsers is not an array of dictionaries: \(property)")
    }
    guard let console = users.first(where: { $0["kCGSSessionOnConsoleKey"] as? Bool == true }) else {
        return ConsoleState(onConsole: false, screenLocked: false)
    }
    return ConsoleState(onConsole: true, screenLocked: console["CGSSessionScreenIsLocked"] as? Bool == true)
}

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let client: DaemonClient
        do {
            client = try DaemonClient()
        } catch {
            // Unsigned, the app cannot prove itself to kasaned, so it has nothing to show.
            let alert = NSAlert()
            alert.messageText = String(localized: "Kasane cannot start")
            alert.informativeText = "\(error)"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        menuBar = MenuBarController(client: client, preferences: Preferences())
    }
}

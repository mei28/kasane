import AppKit
import Combine
import KasaneCore

/// The menu bar icon and its menu. The icon shows whether the built-in keyboard is blocked; the
/// menu rebuilds its items whenever kasaned's status changes.
@MainActor
final class MenuBarController: NSObject {
    private let client: DaemonClient
    private let preferences: Preferences
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settings: SettingsWindowController?
    private var subscription: AnyCancellable?

    init(client: DaemonClient, preferences: Preferences) {
        self.client = client
        self.preferences = preferences
        super.init()
        subscription = client.$status.receive(on: RunLoop.main).sink { [weak self] status in
            MainActor.assumeIsolated { self?.show(status) }
        }
    }

    private func show(_ status: Status?) {
        statusItem.button?.image = icon(for: status)
        statusItem.menu = menu(for: status)
    }

    private func icon(for status: Status?) -> NSImage {
        let state: MenuBarIcon.State =
            switch status {
            case .none: .warning
            case .some(let status) where status.builtInKeyboard != .present || status.configError != nil: .warning
            case .some(let status) where status.isPaused: .paused
            case .some(let status) where status.isOn: .on
            case .some: .off
            }
        return MenuBarIcon.image(state)
    }

    private func menu(for status: Status?) -> NSMenu {
        let menu = NSMenu()
        // The items set isEnabled from kasaned's status; auto-enabling would enable every item with a target.
        menu.autoenablesItems = false
        let line = NSMenuItem(title: MenuText.statusLine(status), action: nil, keyEquivalent: "")
        line.isEnabled = false
        menu.addItem(line)

        if let status {
            menu.addItem(.separator())
            if status.builtInKeyboard == .notPermitted {
                menu.addItem(item(String(localized: "Open Input Monitoring Settings…"), #selector(openInputMonitoring)))
            }
            let block = status.isOn
                ? item(String(localized: "Unblock the Built-in Keyboard"), #selector(unblock))
                : item(String(localized: "Block the Built-in Keyboard"), #selector(block))
            // kasaned refuses unsafe requests anyway; disabling says so before the click.
            block.isEnabled = status.isOn || (!status.isPaused && !status.isRecording && status.safety.permitsBlocking)
            menu.addItem(block)
            menu.addItem(
                status.isPaused
                    ? item(String(localized: "Resume Kasane"), #selector(resume))
                    : item(String(localized: "Pause Kasane"), #selector(pause)))
        }

        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Settings…"), #selector(openSettings), key: ","))
        menu.addItem(item(String(localized: "About Kasane"), #selector(openAbout)))
        menu.addItem(item(String(localized: "Quit Kasane"), #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func block() { client.setBlocked(true) }
    @objc private func unblock() { client.setBlocked(false) }
    @objc private func pause() { client.setPaused(true) }
    @objc private func resume() { client.setPaused(false) }
    @objc private func openInputMonitoring() { MenuText.openInputMonitoringSettings() }

    @objc private func openSettings() {
        let settings = settings ?? SettingsWindowController(preferences: preferences)
        self.settings = settings
        settings.show()
    }

    @objc private func openAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        // Quitting the menu leaves kasaned running; blocking keeps working without the app.
        NSApp.terminate(nil)
    }
}

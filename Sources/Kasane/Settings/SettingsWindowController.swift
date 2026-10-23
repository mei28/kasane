import AppKit
import SwiftUI

/// The settings window, built in AppKit around the SwiftUI view. A SwiftUI Settings scene is not
/// reliably reachable from a menu bar app (LSUIElement), so the window is opened directly.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let model: SettingsModel

    init(client: DaemonClient, preferences: Preferences) {
        model = SettingsModel(client: client)
        let view = SettingsView(model: model, client: client, preferences: preferences)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = String(localized: "Kasane Settings")
        window.styleMask = [.titled, .closable]
        // Keep the window for reopening; it is not released when closed.
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("SettingsWindowController is not built from a coder")
    }

    /// Brings the window forward with the config kasaned has now.
    func show() {
        Task { await model.load() }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

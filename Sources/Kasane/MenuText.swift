import AppKit
import KasaneCore

/// The words the menu and the settings window use for kasaned's status.
enum MenuText {
    /// One line saying what kasane is doing, or what keeps it from working.
    static func statusLine(_ status: Status?) -> String {
        guard let status else { return String(localized: "Cannot reach kasaned") }
        if status.isRecording { return String(localized: "Recording a trigger…") }
        if status.configError != nil { return String(localized: "kasaned cannot use its config file") }
        switch status.builtInKeyboard {
        case .notPermitted: return String(localized: "Input Monitoring is not granted to Kasane")
        case .absent: return String(localized: "No built-in keyboard")
        case .present: break
        }
        if status.isPaused { return String(localized: "Kasane is paused") }
        if status.isOn { return String(localized: "The built-in keyboard is blocked") }
        return String(localized: "The built-in keyboard works")
    }

    static func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        else { preconditionFailure("the Input Monitoring settings URL is malformed") }
        NSWorkspace.shared.open(url)
    }
}

import AppKit
import ServiceManagement

/// The app's own settings in UserDefaults: launch at login and the UI language. Everything that
/// decides blocking lives in kasaned's config instead.
@MainActor
final class Preferences: ObservableObject {
    private enum Key {
        static let launchAtLogin = "kasane.launchAtLogin"
        static let preferredLanguage = "kasane.preferredLanguage"
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            applyLaunchAtLogin()
        }
    }

    @Published var preferredLanguage: AppLanguage {
        didSet {
            defaults.set(preferredLanguage.rawValue, forKey: Key.preferredLanguage)
            applyPreferredLanguage()
        }
    }

    /// Why registering the login item failed, shown under the toggle.
    @Published private(set) var launchAtLoginError: String?

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [Key.launchAtLogin: true, Key.preferredLanguage: AppLanguage.system.rawValue])
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        preferredLanguage = AppLanguage(rawValue: defaults.string(forKey: Key.preferredLanguage) ?? "") ?? .system
        // The user may have turned the login item off in System Settings since.
        if (SMAppService.mainApp.status == .enabled) != launchAtLogin {
            applyLaunchAtLogin()
        }
        applyPreferredLanguage()
    }

    /// Starts a new instance and quits this one, so AppKit strings pick up the language.
    func relaunch() {
        let open = Process()
        open.executableURL = URL(filePath: "/usr/bin/open")
        open.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try open.run()
        } catch {
            NSAlert(error: error).runModal()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
    }

    private func applyPreferredLanguage() {
        switch preferredLanguage {
        case .system: defaults.removeObject(forKey: "AppleLanguages")
        case .english: defaults.set(["en"], forKey: "AppleLanguages")
        case .japanese: defaults.set(["ja"], forKey: "AppleLanguages")
        }
    }
}

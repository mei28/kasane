import KasaneCore
import SwiftUI

/// One row per action, each with a pop-up like the Dictation shortcut in System Settings: the
/// preset, the current custom trigger, and "Customize…" to record a new one.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var client: DaemonClient
    @ObservedObject var preferences: Preferences

    /// What makes the config worth reading again: kasaned coming back, or its file changing state.
    private struct ReloadKey: Equatable {
        let reachable: Bool
        let configError: String?
    }

    var body: some View {
        Form {
            problems
            if let config = model.config {
                slot(.toggle, in: config)
                slot(.externalOff, in: config)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                if let error = preferences.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
                Picker("Language", selection: $preferences.preferredLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Text("The menu bar updates after a relaunch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Relaunch Kasane") { preferences.relaunch() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 520)
        .environment(\.locale, preferences.preferredLanguage.locale)
        .task(id: ReloadKey(reachable: client.status != nil, configError: client.status?.configError)) {
            await model.load()
        }
    }

    /// Shown only while something keeps kasane from working.
    @ViewBuilder private var problems: some View {
        if let status = client.status {
            if status.builtInKeyboard == .notPermitted {
                Section {
                    Text("Input Monitoring is not granted to Kasane")
                    Text("Turn on Kasane under Input Monitoring.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Input Monitoring Settings…") { MenuText.openInputMonitoringSettings() }
                }
            }
            if let error = status.configError {
                Section {
                    Text("kasaned cannot use its config file")
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("Restore the Default Config") { Task { await model.restoreDefaultConfig() } }
                }
            }
        } else {
            Section {
                Text("Cannot reach kasaned")
                Text("kasaned is not running. Install it with just install.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        if let problem = model.configProblem {
            Section {
                Text(problem).foregroundStyle(.red)
            }
        }
    }

    private func slot(_ slot: SettingsModel.Slot, in config: Config) -> some View {
        Section {
            if model.recordingSlot == slot {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Press the new keys. Recording ends one second after you let go.")
                    Spacer()
                    Button("Cancel") { model.cancelRecording() }
                }
            } else {
                Picker("Keys", selection: choice(for: slot, in: config)) {
                    Text(TriggerText.describe(slot.preset, namingKeyboard: slot == .toggle))
                        .tag(SettingsModel.Choice.preset)
                    if config[keyPath: slot.keyPath] != slot.preset {
                        Text(TriggerText.describe(config[keyPath: slot.keyPath], namingKeyboard: slot == .toggle))
                            .tag(SettingsModel.Choice.custom)
                    }
                    Divider()
                    Text("Customize…").tag(SettingsModel.Choice.customize)
                }
                .disabled(model.recordingSlot != nil)
            }
        } header: {
            switch slot {
            case .toggle: Text("Block and Unblock")
            case .externalOff: Text("Unblock from the External Keyboard")
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let problem = model.problems[slot] {
                    Text(problem).foregroundStyle(.red)
                }
                switch slot {
                case .toggle:
                    Text(
                        "Blocks the built-in keyboard, and unblocks it when pressed again. Blocking works only while an external keyboard is connected."
                    )
                case .externalOff:
                    Text(
                        "Unblocks the built-in keyboard from the external one, for when the keys above are out of reach. Only keys pressed on the external keyboard can be recorded."
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func choice(for slot: SettingsModel.Slot, in config: Config) -> Binding<SettingsModel.Choice> {
        Binding(
            get: { model.choice(for: slot, in: config) },
            set: { model.choose($0, for: slot) })
    }
}

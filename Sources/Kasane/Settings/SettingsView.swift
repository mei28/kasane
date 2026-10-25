import KasaneCore
import SwiftUI

/// One section per action, listing its triggers like the shortcut bindings in Wispr Flow: each row
/// can be removed, and "Add…" records a new one. Every change applies at once.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var client: DaemonClient
    @ObservedObject var preferences: Preferences
    @State private var confirmsRestore = false

    /// What makes the config worth reading again: kasaned coming back, or its file changing state.
    private struct ReloadKey: Equatable {
        let reachable: Bool
        let configError: String?
    }

    var body: some View {
        Form {
            problems
            if let config = model.config {
                section(.toggle, in: config)
                section(.externalOff, in: config)
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

            if model.config != nil {
                Section {
                    Button("Restore the Default Config…") { confirmsRestore = true }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 600)
        .confirmationDialog("Restore the default config?", isPresented: $confirmsRestore) {
            Button("Restore", role: .destructive) { Task { await model.restoreDefaultConfig() } }
        } message: {
            Text("The keys you added are removed.")
        }
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
                    Text("The config file is from an older version or damaged.")
                    Text(error).font(.caption).foregroundStyle(.secondary)
                    Button("Restore the Default Config") { Task { await model.restoreDefaultConfig() } }
                }
            }
        } else {
            Section {
                Text("Cannot reach kasaned")
                Text("kasaned is not running. Install it by turning on services.kasane in nix-darwin.")
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

    private func section(_ action: SettingsModel.Action, in config: Config) -> some View {
        Section {
            let triggers = config[keyPath: action.keyPath]
            if triggers.isEmpty {
                Text("None").foregroundStyle(.secondary)
            }
            ForEach(triggers, id: \.self) { trigger in
                HStack {
                    Text(TriggerText.describe(trigger, namingKeyboard: action == .toggle))
                    Spacer()
                    Button {
                        Task { await model.remove(trigger, from: action) }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help(Text("Remove"))
                    .disabled(model.recordingAction != nil || !model.canRemove(from: action, in: config))
                }
            }
            if model.recordingAction == action {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Press the new keys. Recording ends one second after you let go.")
                    Spacer()
                    Button("Cancel") { model.cancelRecording() }
                }
            } else {
                Button("Add…") { Task { await model.add(to: action) } }
                    .disabled(model.recordingAction != nil)
            }
        } header: {
            switch action {
            case .toggle: Text("Block and Unblock")
            case .externalOff: Text("Unblock from the External Keyboard")
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let problem = model.problems[action] {
                    Text(problem).foregroundStyle(.red)
                }
                switch action {
                case .toggle:
                    Text(
                        "Blocks the built-in keyboard, and unblocks it when pressed again. Blocking works only while an external keyboard is connected."
                    )
                case .externalOff:
                    Text(
                        "Unblocks the built-in keyboard from the external one, for when the keys above are out of reach. Only keys pressed on the external keyboard can be recorded."
                    )
                }
                Text("A shortcut also reaches the app in front, so pick one no app uses.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

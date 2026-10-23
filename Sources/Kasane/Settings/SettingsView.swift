import KasaneCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var client: DaemonClient
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
            Section("Triggers") {
                if client.status == nil {
                    Text("Cannot reach kasaned.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.entries.indices, id: \.self) { index in
                        TriggerRow(entry: $model.entries[index]) { model.remove(at: index) }
                    }
                    recordRow
                    footer
                }
            }

            Section("kasaned") {
                Text(MenuText.statusLine(client.status))
                if client.status?.builtInKeyboard == .notPermitted {
                    Text("Add Kasane under Input Monitoring, then wait a few seconds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Input Monitoring Settings…") { MenuText.openInputMonitoringSettings() }
                }
                if let error = client.status?.configError {
                    Text("kasaned could not use its config file: \(error)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .frame(width: 520, height: 600)
        .environment(\.locale, preferences.preferredLanguage.locale)
    }

    @ViewBuilder private var recordRow: some View {
        if model.isRecording {
            HStack {
                ProgressView().controlSize(.small)
                Text("Press the keys for the new trigger. Recording ends one second after you let go.")
                    .font(.callout)
                Spacer()
                Button("Cancel") { model.cancelRecording() }
            }
        } else {
            Button("Record a Trigger…") { Task { await model.record() } }
        }
    }

    @ViewBuilder private var footer: some View {
        if let problem = model.problem {
            Text(problem).font(.caption).foregroundStyle(.red)
        } else if let message = model.message {
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
        HStack {
            Spacer()
            Button("Revert") { model.revert() }
                .disabled(!model.hasChanges)
            Button("Apply") { Task { await model.apply() } }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.hasChanges || model.problem != nil)
        }
    }
}

/// One trigger: what it is, where, its timing, and what it does.
private struct TriggerRow: View {
    @Binding var entry: TriggerEntry
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(TriggerText.gesture(of: entry.trigger))
                    Text(TriggerText.name(of: entry.trigger.device))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $entry.role) {
                    ForEach(TriggerRole.allCases, id: \.self) { role in
                        Text(TriggerText.role(role)).tag(role)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help(Text("Remove"))
            }
            timing
        }
    }

    @ViewBuilder private var timing: some View {
        switch entry.trigger.gesture {
        case .tap:
            Stepper(value: milliseconds, in: 100...3000, step: 50) {
                Text("All taps within \(milliseconds.wrappedValue) ms").font(.caption)
            }
        case .hold:
            Stepper(value: milliseconds, in: 500...5000, step: 100) {
                Text("Held for \(milliseconds.wrappedValue) ms").font(.caption)
            }
        }
    }

    /// The gesture's time, in the units the steppers use.
    private var milliseconds: Binding<Int> {
        Binding(
            get: {
                switch entry.trigger.gesture {
                case .tap(_, _, let window): Int(window / .milliseconds(1))
                case .hold(_, let duration): Int(duration / .milliseconds(1))
                }
            },
            set: { value in
                switch entry.trigger.gesture {
                case .tap(let key, let count, _):
                    entry.trigger.gesture = .tap(key, count: count, within: .milliseconds(value))
                case .hold(let keys, _):
                    entry.trigger.gesture = .hold(keys, for: .milliseconds(value))
                }
            })
    }
}

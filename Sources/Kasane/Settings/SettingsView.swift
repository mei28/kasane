import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Form {
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
}

import Foundation
import KasaneCore

/// The trigger list being edited in the settings window, and the recording in progress.
/// Changes stay local until Apply sends them to kasaned.
@MainActor
final class SettingsModel: ObservableObject {
    @Published var entries: [TriggerEntry] = []
    @Published private(set) var savedEntries: [TriggerEntry] = []
    @Published private(set) var isRecording = false
    /// The latest outcome to show under the list: applied, or why something failed.
    @Published private(set) var message: String?

    let client: DaemonClient

    init(client: DaemonClient) {
        self.client = client
    }

    var hasChanges: Bool { entries != savedEntries }

    /// The rule the edited list breaks, checked with the same rules kasaned applies.
    var problem: String? {
        do {
            try Config(entries: entries, paused: false).validate()
            return nil
        } catch {
            return TriggerText.problem(error)
        }
    }

    func load() async {
        do {
            entries = try await client.config()?.entries ?? []
            savedEntries = entries
            message = nil
        } catch {
            message = String(localized: "Cannot read the config from kasaned: \(error.localizedDescription)")
        }
    }

    func apply() async {
        do {
            switch try await client.apply(Config(entries: entries, paused: false)) {
            case .applied:
                savedEntries = entries
                message = String(localized: "Applied.")
            case .rejected(let error):
                message = TriggerText.problem(error)
            case .unreadable(let reason), .notSaved(let reason):
                message = reason
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func revert() {
        entries = savedEntries
        message = nil
    }

    func record() async {
        isRecording = true
        defer { isRecording = false }
        do {
            switch try await client.record() {
            case .recorded(let trigger):
                // The external keyboard is the usual way back, so its triggers start as OFF only.
                entries.append(TriggerEntry(trigger: trigger, role: trigger.device == .builtIn ? .toggle : .off))
                message = nil
            case .rejected(let error):
                message = TriggerText.problem(error)
            case .cancelled:
                message = nil
            case .busy:
                message = String(localized: "Another recording is in progress.")
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func cancelRecording() {
        client.cancelRecording()
    }

    func remove(at index: Int) {
        entries.remove(at: index)
    }
}

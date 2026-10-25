import Foundation
import KasaneCore

/// The config as kasaned has it, and the recording in progress. Every change goes to kasaned at
/// once, the way macOS applies a new keyboard shortcut; there is nothing to apply or revert.
@MainActor
final class SettingsModel: ObservableObject {
    /// One section of the settings window: an action and the triggers that do it.
    enum Action: CaseIterable {
        case toggle
        case externalOff

        var keyPath: WritableKeyPath<Config, [Trigger]> {
            switch self {
            case .toggle: \.toggle
            case .externalOff: \.externalOff
            }
        }
    }

    /// nil until loaded, and while kasaned has no usable config.
    @Published private(set) var config: Config?
    @Published private(set) var recordingAction: Action?
    /// Why the last change to an action did not happen; its triggers stay as they were.
    @Published private(set) var problems: [Action: String] = [:]
    /// Why the config could not be read or the default config could not be saved.
    @Published private(set) var configProblem: String?

    let client: DaemonClient

    init(client: DaemonClient) {
        self.client = client
    }

    func load() async {
        do {
            config = try await client.config()
            configProblem = nil
        } catch {
            config = nil
            configProblem = String(localized: "Cannot read the config from kasaned: \(error.localizedDescription)")
        }
    }

    /// The external keyboard must keep one way back, so its last trigger stays.
    func canRemove(from action: Action, in config: Config) -> Bool {
        action == .toggle || config.externalOff.count > 1
    }

    func remove(_ trigger: Trigger, from action: Action) async {
        await change(action) { $0[keyPath: action.keyPath].removeAll { $0 == trigger } }
    }

    /// Records a new trigger and adds it to `action`.
    func add(to action: Action) async {
        recordingAction = action
        defer { recordingAction = nil }
        problems[action] = nil
        do {
            switch try await client.record() {
            case .recorded(let trigger):
                await change(action) { $0[keyPath: action.keyPath].append(trigger) }
            case .rejected(let error):
                problems[action] = TriggerText.problem(error)
            case .cancelled:
                break
            case .busy:
                problems[action] = String(localized: "Another recording is in progress.")
            }
        } catch {
            problems[action] = error.localizedDescription
        }
    }

    func cancelRecording() {
        client.cancelRecording()
    }

    /// Saves the default config when kasaned cannot use its file.
    func restoreDefaultConfig() async {
        do {
            switch try await client.apply(.default) {
            case .applied:
                config = .default
                configProblem = nil
            case .rejected(let error):
                preconditionFailure("kasaned rejected the default config: \(error)")
            case .unreadable(let reason), .notSaved(let reason):
                configProblem = reason
            }
        } catch {
            configProblem = error.localizedDescription
        }
    }

    /// Sends the edited config to kasaned when it still passes the rules kasaned applies. A
    /// rejection shows under `action`, and the config stays as it was.
    private func change(_ action: Action, _ edit: (inout Config) -> Void) async {
        guard var newConfig = config else { preconditionFailure("the actions are hidden without a config") }
        edit(&newConfig)
        do {
            try newConfig.validate()
        } catch {
            problems[action] = TriggerText.problem(error)
            return
        }
        do {
            switch try await client.apply(newConfig) {
            case .applied:
                config = newConfig
                problems[action] = nil
            case .rejected(let error):
                problems[action] = TriggerText.problem(error)
            case .unreadable(let reason), .notSaved(let reason):
                problems[action] = reason
            }
        } catch {
            problems[action] = error.localizedDescription
        }
    }
}

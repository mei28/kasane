import Foundation
import KasaneCore

/// The config as kasaned has it, and the recording in progress. Every change goes to kasaned at
/// once, the way macOS applies a new keyboard shortcut; there is nothing to apply or revert.
@MainActor
final class SettingsModel: ObservableObject {
    /// One row of the settings window: an action and the trigger that does it.
    enum Slot: CaseIterable {
        case toggle
        case externalOff

        var keyPath: WritableKeyPath<Config, Trigger> {
            switch self {
            case .toggle: \.toggle
            case .externalOff: \.externalOff
            }
        }

        /// The one trigger the pop-up offers before "Customize…": the default config's.
        var preset: Trigger { Config.default[keyPath: keyPath] }
    }

    /// The items of a slot's pop-up.
    enum Choice: Hashable {
        case preset
        /// The slot's trigger when it is not the preset.
        case custom
        /// Records a new trigger.
        case customize
    }

    /// nil until loaded, and while kasaned has no usable config.
    @Published private(set) var config: Config?
    @Published private(set) var recordingSlot: Slot?
    /// Why the last change to a slot did not happen; the slot keeps its trigger.
    @Published private(set) var problems: [Slot: String] = [:]
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

    func choice(for slot: Slot, in config: Config) -> Choice {
        config[keyPath: slot.keyPath] == slot.preset ? .preset : .custom
    }

    func choose(_ choice: Choice, for slot: Slot) {
        switch choice {
        case .preset:
            Task { await set(slot.preset, in: slot) }
        case .custom:
            break
        case .customize:
            // Set before the task starts, so the pop-up redraws without "Customize…" selected.
            recordingSlot = slot
            Task { await record(for: slot) }
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

    private func record(for slot: Slot) async {
        defer { recordingSlot = nil }
        problems[slot] = nil
        do {
            switch try await client.record() {
            case .recorded(let trigger):
                await set(trigger, in: slot)
            case .rejected(let error):
                problems[slot] = TriggerText.problem(error)
            case .cancelled:
                break
            case .busy:
                problems[slot] = String(localized: "Another recording is in progress.")
            }
        } catch {
            problems[slot] = error.localizedDescription
        }
    }

    private func set(_ trigger: Trigger, in slot: Slot) async {
        await change(slot) { $0[keyPath: slot.keyPath] = trigger }
    }

    /// Sends the edited config to kasaned when it still passes the rules kasaned applies. A
    /// rejection shows under `slot`, and the config stays as it was.
    private func change(_ slot: Slot, _ edit: (inout Config) -> Void) async {
        guard var newConfig = config else { preconditionFailure("the slots are hidden without a config") }
        edit(&newConfig)
        do {
            try newConfig.validate()
        } catch {
            problems[slot] = TriggerText.problem(error)
            return
        }
        do {
            switch try await client.apply(newConfig) {
            case .applied:
                config = newConfig
                problems[slot] = nil
            case .rejected(let error):
                problems[slot] = TriggerText.problem(error)
            case .unreadable(let reason), .notSaved(let reason):
                problems[slot] = reason
            }
        } catch {
            problems[slot] = error.localizedDescription
        }
    }
}

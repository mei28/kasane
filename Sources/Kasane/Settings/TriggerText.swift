import Foundation
import KasaneCore

/// Localized wording for triggers and for the reasons kasaned gives.
enum TriggerText {
    static func name(of key: Key) -> String {
        switch key {
        case .fn: "fn"
        case .leftControl: String(localized: "Left Control")
        case .leftShift: String(localized: "Left Shift")
        case .leftOption: String(localized: "Left Option")
        case .leftCommand: String(localized: "Left Command")
        case .rightControl: String(localized: "Right Control")
        case .rightShift: String(localized: "Right Shift")
        case .rightOption: String(localized: "Right Option")
        case .rightCommand: String(localized: "Right Command")
        }
    }

    static func name(of device: Device) -> String {
        switch device {
        case .builtIn: String(localized: "Built-in keyboard")
        case .external: String(localized: "External keyboard")
        }
    }

    /// The gesture alone, such as "Tap fn 2 times".
    static func gesture(of trigger: Trigger) -> String {
        switch trigger.gesture {
        case .tap(let key, let count, _):
            String(localized: "Tap \(name(of: key)) \(count) times")
        case .hold(let keys, _):
            String(localized: "Hold \(keys.sorted { $0.rawValue < $1.rawValue }.map(name(of:)).joined(separator: " + "))")
        }
    }

    static func role(_ role: TriggerRole) -> String {
        switch role {
        case .toggle: String(localized: "Toggles")
        case .on: String(localized: "Turns on")
        case .off: String(localized: "Turns off")
        }
    }

    static func problem(_ error: ConfigError) -> String {
        switch error {
        case .noExternalOffTrigger:
            String(localized: "Add at least one trigger on the external keyboard that turns Kasane off.")
        case .holdOnBuiltIn:
            String(localized: "The built-in keyboard cannot have hold triggers: the external keyboard's weight could hold a key down.")
        case .unknownKey(let name):
            String(localized: "Unknown key: \(name)")
        case .tapCountOutOfRange(let count):
            String(localized: "A tap trigger needs 2 to 5 taps, not \(count).")
        case .conflictingTapCounts(let key, let device):
            String(localized: "Taps of \(name(of: key)) on the \(name(of: device)) use different counts. Use one count per key.")
        }
    }

    static func problem(_ error: RecordingError) -> String {
        switch error {
        case .nothingRecorded: String(localized: "No key was pressed.")
        case .singleTap: String(localized: "One tap cannot be a trigger. Tap 2 to 5 times.")
        case .tooManyTaps(let count): String(localized: "That was \(count) taps. Tap 2 to 5 times.")
        case .multipleDevices: String(localized: "Keys came from both keyboards. Use one keyboard.")
        case .unsupportedKey: String(localized: "Only fn and the modifier keys can be triggers.")
        case .tapsOnSeveralKeys: String(localized: "Tap one key only.")
        case .holdTooShort: String(localized: "Hold the keys for at least half a second.")
        case .notHeldTogether: String(localized: "Hold all the keys down at the same time.")
        case .keyStillDown: String(localized: "A key was still down when the recording ended.")
        }
    }
}

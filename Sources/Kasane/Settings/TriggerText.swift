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

    /// How a pop-up names a trigger, such as "Press fn 2 times on the built-in keyboard". The
    /// external OFF trigger is always on the external keyboard, so it leaves the keyboard out.
    static func describe(_ trigger: Trigger, namingKeyboard: Bool) -> String {
        switch (trigger.gesture, namingKeyboard ? trigger.device : nil) {
        case (.tap(let key, let count, _), nil):
            String(localized: "Press \(name(of: key)) \(count) times")
        case (.tap(let key, let count, _), .builtIn):
            String(localized: "Press \(name(of: key)) \(count) times on the built-in keyboard")
        case (.tap(let key, let count, _), .external):
            String(localized: "Press \(name(of: key)) \(count) times on the external keyboard")
        case (.hold(let held, let duration), nil):
            String(localized: "Hold \(keys(held)) for \(seconds(duration)) s")
        case (.hold(let held, let duration), .builtIn):
            String(localized: "Hold \(keys(held)) for \(seconds(duration)) s on the built-in keyboard")
        case (.hold(let held, let duration), .external):
            String(localized: "Hold \(keys(held)) for \(seconds(duration)) s on the external keyboard")
        case (.shortcut(let modifiers, let key), nil):
            String(localized: "Press \(shortcut(modifiers, key))")
        case (.shortcut(let modifiers, let key), .builtIn):
            String(localized: "Press \(shortcut(modifiers, key)) on the built-in keyboard")
        case (.shortcut(let modifiers, let key), .external):
            String(localized: "Press \(shortcut(modifiers, key)) on the external keyboard")
        }
    }

    /// A shortcut as macOS writes it, such as ⌃⌥⌘K.
    private static func shortcut(_ modifiers: Set<Modifier>, _ key: ShortcutKey) -> String {
        Modifier.allCases.filter(modifiers.contains).map(symbol(of:)).joined() + label(of: key)
    }

    private static func symbol(of modifier: Modifier) -> String {
        switch modifier {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }

    /// The key as macOS menus show it: symbols for the keys that have one, capitals for letters.
    private static func label(of key: ShortcutKey) -> String {
        switch key {
        case .return: "↩"
        case .escape: "⎋"
        case .delete: "⌫"
        case .tab: "⇥"
        case .space: String(localized: "Space")
        case .left: "←"
        case .right: "→"
        case .up: "↑"
        case .down: "↓"
        default: key.rawValue.uppercased()
        }
    }

    /// Keys held together, as "both Shift keys" when a modifier is held on both sides.
    private static func keys(_ keys: Set<Key>) -> String {
        let groups: [(keys: [Key], both: String?)] = [
            ([.fn], nil),
            ([.leftControl, .rightControl], String(localized: "both Control keys")),
            ([.leftOption, .rightOption], String(localized: "both Option keys")),
            ([.leftShift, .rightShift], String(localized: "both Shift keys")),
            ([.leftCommand, .rightCommand], String(localized: "both Command keys")),
        ]
        var names: [String] = []
        for group in groups {
            if let both = group.both, group.keys.allSatisfy(keys.contains) {
                names.append(both)
            } else {
                names += group.keys.filter(keys.contains).map(name(of:))
            }
        }
        return names.joined(separator: " + ")
    }

    /// Whole seconds, or tenths when the duration has them: "1", "1.5".
    private static func seconds(_ duration: Duration) -> String {
        (duration / .seconds(1)).formatted(.number.precision(.fractionLength(0...1)))
    }

    static func name(of device: Device) -> String {
        switch device {
        case .builtIn: String(localized: "Built-in keyboard")
        case .external: String(localized: "External keyboard")
        }
    }

    static func problem(_ error: ConfigError) -> String {
        switch error {
        case .noExternalOffTrigger:
            String(localized: "Keep at least one way back on the external keyboard.")
        case .shortcutNeedsCommandOrControl:
            String(localized: "A shortcut needs ⌃ or ⌘.")
        case .duplicateTrigger:
            String(localized: "These keys are already in the list.")
        case .externalOffOnBuiltIn:
            String(localized: "Press the keys on the external keyboard.")
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
        case .unsupportedKey:
            String(
                localized:
                    "This key cannot be used. Use letters, digits, Space, Return, Tab, Escape, Delete, the arrow keys, fn, or the modifier keys."
            )
        case .severalKeys: String(localized: "A shortcut ends with one key, such as K in ⌃⌥⌘K.")
        case .fnInShortcut: String(localized: "fn cannot be part of a shortcut.")
        case .tapsOnSeveralKeys: String(localized: "Tap one key only.")
        case .holdTooShort: String(localized: "Hold the keys for at least half a second.")
        case .notHeldTogether: String(localized: "Hold all the keys down at the same time.")
        case .keyStillDown: String(localized: "A key was still down when the recording ended.")
        }
    }
}

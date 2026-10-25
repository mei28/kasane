public enum Key: String, CaseIterable, Sendable {
    case fn
    case leftControl
    case leftShift
    case leftOption
    case leftCommand
    case rightControl
    case rightShift
    case rightOption
    case rightCommand
}

extension Key {
    public var usage: HIDUsage {
        switch self {
        case .fn: HIDUsage(page: 0xFF, usage: 0x03)
        case .leftControl: HIDUsage(page: 0x07, usage: 0xE0)
        case .leftShift: HIDUsage(page: 0x07, usage: 0xE1)
        case .leftOption: HIDUsage(page: 0x07, usage: 0xE2)
        case .leftCommand: HIDUsage(page: 0x07, usage: 0xE3)
        case .rightControl: HIDUsage(page: 0x07, usage: 0xE4)
        case .rightShift: HIDUsage(page: 0x07, usage: 0xE5)
        case .rightOption: HIDUsage(page: 0x07, usage: 0xE6)
        case .rightCommand: HIDUsage(page: 0x07, usage: 0xE7)
        }
    }

    /// The key a HID usage stands for, or nil when kasane has no name for it.
    public init?(usage: HIDUsage) {
        guard let key = Key.allCases.first(where: { $0.usage == usage }) else { return nil }
        self = key
    }
}

/// A modifier in a keyboard shortcut. Either side's key counts, as in any macOS shortcut. The
/// cases are in the order macOS writes them: ⌃⌥⇧⌘.
public enum Modifier: String, CaseIterable, Sendable {
    case control
    case option
    case shift
    case command
}

extension Key {
    /// The modifier this key stands for in a shortcut; nil for fn.
    public var modifier: Modifier? {
        switch self {
        case .fn: nil
        case .leftControl, .rightControl: .control
        case .leftOption, .rightOption: .option
        case .leftShift, .rightShift: .shift
        case .leftCommand, .rightCommand: .command
        }
    }
}

extension Key: Codable {
    public init(from decoder: any Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        guard let key = Key(rawValue: name) else {
            throw ConfigError.unknownKey(name)
        }
        self = key
    }
}

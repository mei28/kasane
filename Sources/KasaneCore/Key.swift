public enum Key: String, Sendable {
    case fn
    case leftShift
    case rightShift
    case rightCommand
}

extension Key {
    public var usage: HIDUsage {
        switch self {
        case .fn: HIDUsage(page: 0xFF, usage: 0x03)
        case .leftShift: HIDUsage(page: 0x07, usage: 0xE1)
        case .rightShift: HIDUsage(page: 0x07, usage: 0xE5)
        case .rightCommand: HIDUsage(page: 0x07, usage: 0xE7)
        }
    }
}

extension Key: Decodable {
    public init(from decoder: any Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        guard let key = Key(rawValue: name) else {
            throw ConfigError.unknownKey(name)
        }
        self = key
    }
}

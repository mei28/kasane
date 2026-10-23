public enum Key: String, Sendable {
    case fn
    case leftShift
    case rightShift
    case rightCommand
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

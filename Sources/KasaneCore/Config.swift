import Foundation

public struct Config: Equatable, Sendable {
    public var externalKeyboards: [ExternalKeyboard]
    public var on: [Trigger]
    public var off: [Trigger]

    public init(externalKeyboards: [ExternalKeyboard], on: [Trigger], off: [Trigger]) {
        self.externalKeyboards = externalKeyboards
        self.on = on
        self.off = off
    }

    public static func parse(_ data: Data) throws -> Config {
        let config = try JSONDecoder().decode(Config.self, from: data)
        try config.validate()
        return config
    }

    private func validate() throws(ConfigError) {
        // With no allowlisted keyboard, the safety conditions can never hold.
        guard !externalKeyboards.isEmpty else {
            throw .noExternalKeyboards
        }
        guard off.contains(where: { $0.device == .external }) else {
            throw .noExternalOffTrigger
        }
        // Typing on the external keyboard can press built-in keys, which could turn kasane off.
        guard off.allSatisfy({ $0.device == .external }) else {
            throw .builtInOffTrigger
        }
        // The external keyboard's weight alone could hold a built-in key down.
        for trigger in on where trigger.device == .builtIn {
            if case .hold = trigger.gesture { throw .holdOnBuiltIn }
        }
    }
}

/// A config that could leave the user without a working keyboard. kasaned refuses to start on
/// any of these, so it never seizes the built-in keyboard with a bad config.
public enum ConfigError: Error, Equatable {
    case noExternalKeyboards
    case noExternalOffTrigger
    case holdOnBuiltIn
    case builtInOffTrigger
    case unknownKey(String)
}

extension Config: Decodable {}

public struct ExternalKeyboard: Decodable, Equatable, Sendable {
    public var name: String
    public var vendorID: Int
    public var productID: Int

    public init(name: String, vendorID: Int, productID: Int) {
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
    }
}

public enum Device: String, Decodable, Sendable {
    case builtIn
    case external
}

public struct Trigger: Equatable, Sendable {
    public var device: Device
    public var gesture: Gesture

    public init(device: Device, gesture: Gesture) {
        self.device = device
        self.gesture = gesture
    }
}

public enum Gesture: Equatable, Sendable {
    case doubleTap(Key, within: Duration)
    case hold(Set<Key>, for: Duration)
}

extension Trigger: Decodable {
    private enum CodingKeys: String, CodingKey {
        case device, gesture, key, withinMs, keys, forMs
    }

    private enum GestureName: String, Decodable {
        case doubleTap
        case hold
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = try container.decode(Device.self, forKey: .device)
        switch try container.decode(GestureName.self, forKey: .gesture) {
        case .doubleTap:
            gesture = .doubleTap(
                try container.decode(Key.self, forKey: .key),
                within: .milliseconds(try container.decode(Int.self, forKey: .withinMs)))
        case .hold:
            gesture = .hold(
                try container.decode(Set<Key>.self, forKey: .keys),
                for: .milliseconds(try container.decode(Int.self, forKey: .forMs)))
        }
    }
}

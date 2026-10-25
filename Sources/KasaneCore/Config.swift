import Foundation

/// The two actions the settings window sets, each with its triggers: switching the built-in
/// keyboard, and the way back from the external keyboard.
public struct Config: Codable, Equatable, Sendable {
    /// Each turns ON while OFF and OFF while ON.
    public var toggle: [Trigger]
    /// Each turns OFF from the external keyboard, for when the toggle is out of reach.
    public var externalOff: [Trigger]
    /// Paused, kasane ignores every trigger and keeps the built-in keyboard working.
    public var paused: Bool

    public init(toggle: [Trigger], externalOff: [Trigger], paused: Bool = false) {
        self.toggle = toggle
        self.externalOff = externalOff
        self.paused = paused
    }

    /// What kasaned writes on its first start: fn tapped twice on the built-in keyboard toggles,
    /// and both Shift keys held on the external keyboard turn OFF.
    public static let `default` = Config(
        toggle: [Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))],
        externalOff: [Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1000)))])

    public static func parse(_ data: Data) throws -> Config {
        let config = try JSONDecoder().decode(Config.self, from: data)
        try config.validate()
        return config
    }

    /// JSON that `parse` reads back to the same config. Sorted keys keep the file diffable.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Throws the first rule this config breaks. parse runs it on every config it reads.
    public func validate() throws(ConfigError) {
        guard !externalOff.isEmpty else {
            throw .noExternalOffTrigger
        }
        let triggers: [(trigger: Trigger, isExternalOff: Bool)] =
            toggle.map { ($0, false) } + externalOff.map { ($0, true) }
        for entry in triggers {
            try Self.check(entry.trigger, isExternalOff: entry.isExternalOff)
        }
        for (index, entry) in triggers.enumerated() {
            for other in triggers[(index + 1)...] {
                try Self.check(entry.trigger, against: other.trigger)
            }
        }
    }

    /// The rules for one trigger on its own.
    private static func check(_ trigger: Trigger, isExternalOff: Bool) throws(ConfigError) {
        if isExternalOff, trigger.device != .external {
            throw .externalOffOnBuiltIn
        }
        // The external keyboard's weight alone could hold a built-in key down.
        if trigger.device == .builtIn, case .hold = trigger.gesture {
            throw .holdOnBuiltIn
        }
        // One tap fires on ordinary use of the key, and more than five is hard to hit reliably.
        if case .tap(_, let count, _) = trigger.gesture, !(2...5).contains(count) {
            throw .tapCountOutOfRange(count)
        }
    }

    /// The rules for two triggers together.
    private static func check(_ trigger: Trigger, against other: Trigger) throws(ConfigError) {
        // Different counts on one key fire the shorter one on the way to the longer one.
        if case .tap(let key, let count, _) = trigger.gesture,
            case .tap(let otherKey, let otherCount, _) = other.gesture,
            trigger.device == other.device, key == otherKey, count != otherCount
        {
            throw .conflictingTapCounts(key, trigger.device)
        }
        // Two rows that read the same would be one trigger listed twice.
        if trigger.matchesIgnoringTiming(other) {
            throw .duplicateTrigger
        }
    }
}

/// A config that could leave the user without a working keyboard. kasaned runs without triggers
/// rather than use one, and the app checks each change against these before sending it.
public enum ConfigError: Error, Codable, Equatable, Sendable {
    case noExternalOffTrigger
    case externalOffOnBuiltIn
    case holdOnBuiltIn
    case unknownKey(String)
    case tapCountOutOfRange(Int)
    case conflictingTapCounts(Key, Device)
    case duplicateTrigger
}

public enum Device: String, Codable, Sendable {
    case builtIn
    case external
}

public struct Trigger: Hashable, Sendable {
    public var device: Device
    public var gesture: Gesture

    public init(device: Device, gesture: Gesture) {
        self.device = device
        self.gesture = gesture
    }
}

extension Trigger {
    /// Whether two triggers read the same in the settings window: the same keyboard, keys, and
    /// count, whatever their timing.
    fileprivate func matchesIgnoringTiming(_ other: Trigger) -> Bool {
        guard device == other.device else { return false }
        switch (gesture, other.gesture) {
        case (.tap(let key, let count, _), .tap(let otherKey, let otherCount, _)):
            return key == otherKey && count == otherCount
        case (.hold(let keys, _), .hold(let otherKeys, _)):
            return keys == otherKeys
        case (.tap, .hold), (.hold, .tap):
            return false
        }
    }
}

public enum Gesture: Hashable, Sendable {
    /// `count` presses of one key, the last within `within` of the first.
    case tap(Key, count: Int, within: Duration)
    case hold(Set<Key>, for: Duration)
}

extension Trigger: Codable {
    private enum CodingKeys: String, CodingKey {
        case device, gesture, key, count, withinMs, keys, forMs
    }

    private enum GestureName: String, Codable {
        case tap
        case hold
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = try container.decode(Device.self, forKey: .device)
        switch try container.decode(GestureName.self, forKey: .gesture) {
        case .tap:
            gesture = .tap(
                try container.decode(Key.self, forKey: .key),
                count: try container.decode(Int.self, forKey: .count),
                within: .milliseconds(try container.decode(Int.self, forKey: .withinMs)))
        case .hold:
            gesture = .hold(
                try container.decode(Set<Key>.self, forKey: .keys),
                for: .milliseconds(try container.decode(Int.self, forKey: .forMs)))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(device, forKey: .device)
        switch gesture {
        case .tap(let key, let count, let window):
            try container.encode(GestureName.tap, forKey: .gesture)
            try container.encode(key, forKey: .key)
            try container.encode(count, forKey: .count)
            try container.encode(window.wholeMilliseconds, forKey: .withinMs)
        case .hold(let keys, let duration):
            try container.encode(GestureName.hold, forKey: .gesture)
            try container.encode(keys.sorted { $0.rawValue < $1.rawValue }, forKey: .keys)
            try container.encode(duration.wholeMilliseconds, forKey: .forMs)
        }
    }
}

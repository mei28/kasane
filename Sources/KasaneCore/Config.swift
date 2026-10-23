import Foundation

public struct Config: Equatable, Sendable {
    public var on: [Trigger]
    public var off: [Trigger]
    /// Paused, kasane ignores every trigger and keeps the built-in keyboard working.
    public var paused: Bool

    public init(on: [Trigger], off: [Trigger], paused: Bool = false) {
        self.on = on
        self.off = off
        self.paused = paused
    }

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

    private func validate() throws(ConfigError) {
        guard off.contains(where: { $0.device == .external }) else {
            throw .noExternalOffTrigger
        }
        // The external keyboard's weight alone could hold a built-in key down.
        for trigger in on + off where trigger.device == .builtIn {
            if case .hold = trigger.gesture { throw .holdOnBuiltIn }
        }
        // One tap fires on ordinary use of the key, and more than five is hard to hit reliably.
        for trigger in on + off {
            if case .tap(_, let count, _) = trigger.gesture, !(2...5).contains(count) {
                throw .tapCountOutOfRange(count)
            }
        }
        // Different counts on one key fire the shorter one on the way to the longer one.
        var tapCounts: [TapSlot: Int] = [:]
        for trigger in on + off {
            guard case .tap(let key, let count, _) = trigger.gesture else { continue }
            let slot = TapSlot(device: trigger.device, key: key)
            if let seen = tapCounts[slot], seen != count {
                throw .conflictingTapCounts(key, trigger.device)
            }
            tapCounts[slot] = count
        }
    }

    private struct TapSlot: Hashable {
        let device: Device
        let key: Key
    }
}

/// A config that could leave the user without a working keyboard. kasaned refuses to start on
/// any of these, so it never seizes the built-in keyboard with a bad config.
public enum ConfigError: Error, Equatable {
    case noExternalOffTrigger
    case holdOnBuiltIn
    case unknownKey(String)
    case tapCountOutOfRange(Int)
    case conflictingTapCounts(Key, Device)
}

extension Config: Codable {
    private enum CodingKeys: String, CodingKey {
        case on, off, paused
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        on = try container.decode([Trigger].self, forKey: .on)
        off = try container.decode([Trigger].self, forKey: .off)
        // A config written before pausing existed, or by hand, is not paused.
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    }
}

public enum Device: String, Codable, Sendable {
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
            try container.encode(Self.milliseconds(window), forKey: .withinMs)
        case .hold(let keys, let duration):
            try container.encode(GestureName.hold, forKey: .gesture)
            try container.encode(keys.sorted { $0.rawValue < $1.rawValue }, forKey: .keys)
            try container.encode(Self.milliseconds(duration), forKey: .forMs)
        }
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let (seconds, attoseconds) = duration.components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}

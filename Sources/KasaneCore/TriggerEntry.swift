/// What a trigger does, as the settings window shows it.
public enum TriggerRole: String, CaseIterable, Codable, Sendable {
    /// Listed under both `on` and `off`: the gesture switches between them.
    case toggle
    case on
    case off
}

/// One row of the settings window's trigger list.
public struct TriggerEntry: Equatable, Sendable {
    public var trigger: Trigger
    public var role: TriggerRole

    public init(trigger: Trigger, role: TriggerRole) {
        self.trigger = trigger
        self.role = role
    }
}

extension Config {
    /// The triggers in `on` order, then the ones only in `off`, each with its role.
    public var entries: [TriggerEntry] {
        on.map { TriggerEntry(trigger: $0, role: off.contains($0) ? .toggle : .on) }
            + off.filter { !on.contains($0) }.map { TriggerEntry(trigger: $0, role: .off) }
    }
}

extension Config {
    /// The config the settings window's rows describe. A toggle goes under both lists.
    public init(entries: [TriggerEntry], paused: Bool) {
        self.init(
            on: entries.filter { $0.role != .off }.map(\.trigger),
            off: entries.filter { $0.role != .on }.map(\.trigger),
            paused: paused)
    }
}

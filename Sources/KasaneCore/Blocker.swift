/// The facts that decide whether blocking the built-in keyboard is safe.
public struct Safety: Equatable, Sendable {
    public var externalKeyboardConnected: Bool
    public var screenLocked: Bool
    public var onConsole: Bool
    public var asleep: Bool

    public init(externalKeyboardConnected: Bool, screenLocked: Bool, onConsole: Bool, asleep: Bool) {
        self.externalKeyboardConnected = externalKeyboardConnected
        self.screenLocked = screenLocked
        self.onConsole = onConsole
        self.asleep = asleep
    }

    /// Blocking is safe only while some keyboard other than the built-in one can still type.
    public var permitsBlocking: Bool {
        externalKeyboardConnected && !screenLocked && onConsole && !asleep
    }
}

/// What kasaned must do to the built-in keyboard. kasaned runs them in order and stops at the
/// first failure.
public enum Effect: Equatable, Sendable {
    case seize
    case ledOn
    case ledOff
    case release
}

/// Decides when the built-in keyboard is blocked (ON) and what kasaned must do about it.
public struct Blocker: Sendable {
    public private(set) var isOn = false
    private var safety: Safety

    public init(safety: Safety) {
        self.safety = safety
    }

    public mutating func onTrigger() -> [Effect] {
        guard !isOn, safety.permitsBlocking else { return [] }
        isOn = true
        return [.seize, .ledOn]
    }

    public mutating func offTrigger() -> [Effect] {
        guard isOn else { return [] }
        return turnOff()
    }

    public mutating func update(_ safety: Safety) -> [Effect] {
        self.safety = safety
        guard isOn, !safety.permitsBlocking else { return [] }
        return turnOff()
    }

    /// kasaned no longer holds the built-in keyboard: seizing it failed, or it disappeared. There
    /// is nothing left to release or light.
    public mutating func lostSeize() {
        isOn = false
    }

    private mutating func turnOff() -> [Effect] {
        isOn = false
        return [.ledOff, .release]
    }
}

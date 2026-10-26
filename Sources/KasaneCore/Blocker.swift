/// The facts that decide whether blocking the built-in keyboard is safe. Blocking needs no external
/// keyboard, but losing the last one turns it OFF (`Blocker.update`).
public struct Safety: Codable, Equatable, Sendable {
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

    public var permitsBlocking: Bool {
        !screenLocked && onConsole && !asleep
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
    public private(set) var isPaused: Bool
    private var safety: Safety

    public init(safety: Safety, paused: Bool = false) {
        self.safety = safety
        isPaused = paused
    }

    public mutating func onTrigger() -> [Effect] {
        guard !isOn, !isPaused, safety.permitsBlocking else { return [] }
        isOn = true
        return [.seize, .ledOn]
    }

    public mutating func offTrigger() -> [Effect] {
        guard isOn else { return [] }
        return turnOff()
    }

    /// Handles the triggers that fired on one event. Only the triggers that can change the current
    /// state count, so one gesture listed under both `on` and `off` toggles.
    public mutating func triggered(on: Bool, off: Bool) -> [Effect] {
        if isOn {
            off ? offTrigger() : []
        } else {
            on ? onTrigger() : []
        }
    }

    /// Turns OFF when blocking stops being safe, or when the last external keyboard goes: it may
    /// be the one the user types on. Blocking that started without one lasts while none is there.
    public mutating func update(_ safety: Safety) -> [Effect] {
        let lostLastExternalKeyboard = self.safety.externalKeyboardConnected && !safety.externalKeyboardConnected
        self.safety = safety
        guard isOn, !safety.permitsBlocking || lostLastExternalKeyboard else { return [] }
        return turnOff()
    }

    public mutating func pause() -> [Effect] {
        isPaused = true
        return isOn ? turnOff() : []
    }

    /// Resuming leaves kasane OFF; the next ON trigger turns it ON.
    public mutating func resume() {
        isPaused = false
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

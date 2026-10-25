/// Watches key events for one trigger and reports when its gesture completes.
public struct TriggerRecognizer: Sendable {
    private let device: Device
    private var gesture: any GestureRecognizer

    public init(_ trigger: Trigger) {
        device = trigger.device
        switch trigger.gesture {
        case .tap(let key, let count, let window):
            gesture = Tap(usage: key.usage, count: count, window: window)
        case .hold(let keys, let duration):
            gesture = Hold(usages: Set(keys.map(\.usage)), duration: duration)
        case .shortcut(let modifiers, let key):
            gesture = Shortcut(modifiers: modifiers, key: key.usage)
        }
    }

    /// Returns true when this event completes the gesture.
    public mutating func handle(_ event: KeyEvent) -> Bool {
        // Keys on the other keyboard neither count toward nor interrupt this trigger.
        guard event.device == device else { return false }
        return gesture.handle(event)
    }

    /// Returns true when the gesture completes at `time` without a new event.
    public mutating func advance(to time: Duration) -> Bool {
        gesture.advance(to: time)
    }
}

private protocol GestureRecognizer: Sendable {
    mutating func handle(_ event: KeyEvent) -> Bool
    mutating func advance(to time: Duration) -> Bool
}

/// `count` presses and releases of one key, with the last press within `window` of the first.
private struct Tap: GestureRecognizer {
    let usage: HIDUsage
    let count: Int
    let window: Duration
    private var firstDownAt: Duration?
    private var presses = 0
    private var isDown = false

    init(usage: HIDUsage, count: Int, window: Duration) {
        self.usage = usage
        self.count = count
        self.window = window
    }

    mutating func handle(_ event: KeyEvent) -> Bool {
        guard event.usage == usage else {
            if event.isDown { startOver() }
            return false
        }
        if event.isDown {
            if let start = firstDownAt, event.time - start <= window {
                presses += 1
            } else {
                // A press past the window starts a new attempt.
                firstDownAt = event.time
                presses = 1
            }
            isDown = true
            return false
        }
        // A release without a press is one held before observation started.
        guard isDown else { return false }
        isDown = false
        guard presses == count else { return false }
        startOver()
        return true
    }

    private mutating func startOver() {
        firstDownAt = nil
        presses = 0
        isDown = false
    }

    func advance(to time: Duration) -> Bool {
        false
    }
}

/// All keys down together for `duration`.
private struct Hold: GestureRecognizer {
    let usages: Set<HIDUsage>
    let duration: Duration
    private var pressed: Set<HIDUsage> = []
    private var allDownSince: Duration?

    init(usages: Set<HIDUsage>, duration: Duration) {
        self.usages = usages
        self.duration = duration
    }

    mutating func handle(_ event: KeyEvent) -> Bool {
        guard usages.contains(event.usage) else {
            if event.isDown { allDownSince = nil }
            return false
        }
        if event.isDown {
            pressed.insert(event.usage)
        } else {
            pressed.remove(event.usage)
        }
        allDownSince = pressed == usages ? event.time : nil
        return false
    }

    mutating func advance(to time: Duration) -> Bool {
        guard let since = allDownSince, time - since >= duration else { return false }
        allDownSince = nil
        return true
    }
}

/// A shortcut key pressed while exactly the given modifiers are held, such as ⌃⌥⌘K. It completes
/// only once every key of it is up again and the shortcut key was down for under a second.
///
/// Waiting for every key to come up means no key of the keyboard is down when kasaned seizes or
/// releases it, so none can stay stuck; the time limit keeps the external keyboard's weight, which
/// holds keys far longer, from completing it.
private struct Shortcut: GestureRecognizer {
    static let longestPress: Duration = .seconds(1)

    let modifiers: Set<Modifier>
    let key: HIDUsage
    /// fn and the modifier keys seen going down and not yet up.
    private var held: Set<Key> = []
    /// When the shortcut key went down with exactly the modifiers held; nil while no attempt runs.
    private var keyDownAt: Duration?
    /// Whether the shortcut key of the running attempt came up in time.
    private var keyReleased = false

    init(modifiers: Set<Modifier>, key: HIDUsage) {
        self.modifiers = modifiers
        self.key = key
    }

    mutating func handle(_ event: KeyEvent) -> Bool {
        if let pressed = Key(usage: event.usage) {
            if event.isDown {
                held.insert(pressed)
                // A modifier added during an attempt makes it another shortcut.
                startOver()
            } else {
                held.remove(pressed)
            }
        } else if event.usage == key {
            if event.isDown {
                startOver()
                // fn counts as a modifier the shortcut does not have.
                if Set(held.compactMap(\.modifier)) == modifiers, !held.contains(.fn) {
                    keyDownAt = event.time
                }
            } else if let downAt = keyDownAt {
                if event.time - downAt < Self.longestPress {
                    keyReleased = true
                } else {
                    startOver()
                }
            }
        } else if event.isDown {
            // Another key makes it another shortcut. Releases alone, such as the built-in
            // keyboard's usage 0x01 after most keys, change nothing.
            startOver()
        }
        guard keyReleased, held.isEmpty else { return false }
        startOver()
        return true
    }

    private mutating func startOver() {
        keyDownAt = nil
        keyReleased = false
    }

    func advance(to time: Duration) -> Bool {
        false
    }
}

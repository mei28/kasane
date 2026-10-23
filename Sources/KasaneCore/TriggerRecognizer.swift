/// Watches key events for one trigger and reports when its gesture completes.
public struct TriggerRecognizer: Sendable {
    private let device: Device
    private var gesture: any GestureRecognizer

    public init(_ trigger: Trigger) {
        device = trigger.device
        switch trigger.gesture {
        case .doubleTap(let key, let window):
            gesture = DoubleTap(usage: key.usage, window: window)
        case .hold(let keys, let duration):
            gesture = Hold(usages: Set(keys.map(\.usage)), duration: duration)
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

/// Down, up, down, up on one key, with the second down within `window` of the first.
private struct DoubleTap: GestureRecognizer {
    private enum Phase {
        case idle
        case firstDown(at: Duration)
        case firstUp(firstDownAt: Duration)
        case secondDown
    }

    let usage: HIDUsage
    let window: Duration
    private var phase = Phase.idle

    init(usage: HIDUsage, window: Duration) {
        self.usage = usage
        self.window = window
    }

    mutating func handle(_ event: KeyEvent) -> Bool {
        guard event.usage == usage else {
            if event.isDown { phase = .idle }
            return false
        }
        switch (phase, event.isDown) {
        case (.idle, true): phase = .firstDown(at: event.time)
        case (.firstDown(let start), false): phase = .firstUp(firstDownAt: start)
        case (.firstUp(let start), true):
            phase = event.time - start <= window ? .secondDown : .firstDown(at: event.time)
        case (.secondDown, false):
            phase = .idle
            return true
        default: break
        }
        return false
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

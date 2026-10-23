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

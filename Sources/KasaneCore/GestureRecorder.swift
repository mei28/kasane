/// Why a recording did not become a trigger.
public enum RecordingError: Error, Codable, Equatable, Sendable {
    case nothingRecorded
    case singleTap
    case tooManyTaps(Int)
    case multipleDevices
    case unsupportedKey(HIDUsage)
    case tapsOnSeveralKeys
    case holdTooShort
    case notHeldTogether
    case keyStillDown
}

/// Turns the keys pressed while recording into a trigger: repeated presses of one key become a
/// tap, keys held down become a hold.
public struct GestureRecorder: Sendable {
    private struct Press: Sendable {
        let usage: HIDUsage
        let device: Device
        let down: Duration
        var up: Duration?
    }

    private let startedAt: Duration
    private var presses: [Press] = []

    public init(startedAt: Duration) {
        self.startedAt = startedAt
    }

    public mutating func record(_ event: KeyEvent) {
        if event.isDown {
            presses.append(Press(usage: event.usage, device: event.device, down: event.time))
        } else if let index = presses.lastIndex(where: {
            $0.usage == event.usage && $0.device == event.device && $0.up == nil
        }) {
            presses[index].up = event.time
        }
    }

    /// Whether the user is done: no key is down and a second has passed since the last release.
    /// A recording also ends 15 seconds after it started, so it never runs on unattended.
    public func isFinished(at time: Duration) -> Bool {
        if time - startedAt >= .seconds(15) { return true }
        guard let lastUp = presses.compactMap(\.up).max(), presses.allSatisfy({ $0.up != nil }) else {
            return false
        }
        return time - lastUp >= .seconds(1)
    }

    public func result() -> Result<Trigger, RecordingError> {
        guard let first = presses.first else { return .failure(.nothingRecorded) }
        guard presses.allSatisfy({ $0.device == first.device }) else { return .failure(.multipleDevices) }
        guard presses.allSatisfy({ $0.up != nil }) else { return .failure(.keyStillDown) }
        var keys: [Key] = []
        for press in presses {
            guard let key = Key(usage: press.usage) else { return .failure(.unsupportedKey(press.usage)) }
            keys.append(key)
        }
        return tapOrHold(keys, on: first.device)
    }

    /// Presses of fn and modifier keys: repeated presses of one key, or keys held down together.
    private func tapOrHold(_ keys: [Key], on device: Device) -> Result<Trigger, RecordingError> {
        let first = presses[0]
        if overlaps || heldLong {
            // Held together from the last press to the first release, in steps of 100 ms.
            let lastDown = presses.map(\.down).max()!
            let firstUp = presses.compactMap(\.up).min()!
            guard lastDown < firstUp else { return .failure(.notHeldTogether) }
            let held = (firstUp - lastDown).wholeMilliseconds / 100 * 100
            guard held >= Self.holdThreshold.wholeMilliseconds else { return .failure(.holdTooShort) }
            return .success(Trigger(device: device, gesture: .hold(Set(keys), for: .milliseconds(held))))
        }
        guard presses.count >= 2 else { return .failure(.singleTap) }
        guard presses.count <= 5 else { return .failure(.tooManyTaps(presses.count)) }
        let key = keys[0]
        guard keys.allSatisfy({ $0 == key }) else { return .failure(.tapsOnSeveralKeys) }
        let span = (presses[presses.count - 1].down - first.down).wholeMilliseconds
        // Half again the measured span leaves room for a slower attempt, in steps of 50 ms.
        let window = (span * 3 / 2 + 49) / 50 * 50
        return .success(
            Trigger(device: device, gesture: .tap(key, count: presses.count, within: .milliseconds(window))))
    }

    /// A press this long is a hold, not a tap.
    private static let holdThreshold: Duration = .milliseconds(500)

    private var heldLong: Bool {
        presses.contains { press in press.up.map { $0 - press.down >= Self.holdThreshold } ?? true }
    }

    /// Whether some key went down while another was still down.
    private var overlaps: Bool {
        presses.contains { earlier in
            presses.contains { later in
                earlier.down < later.down && earlier.up.map { later.down < $0 } ?? true
            }
        }
    }
}

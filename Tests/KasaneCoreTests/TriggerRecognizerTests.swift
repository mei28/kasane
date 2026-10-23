import KasaneCore
import Testing

private let fnDoubleTap = Trigger(device: .builtIn, gesture: .doubleTap(.fn, within: .milliseconds(400)))
private let shiftsHeld = Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1000)))
private let letterA = HIDUsage(page: 0x07, usage: 0x04)

private enum Step {
    case key(KeyEvent)
    case tick(Duration)
}

private func down(_ usage: HIDUsage, at ms: Int, on device: Device = .builtIn) -> Step {
    .key(KeyEvent(device: device, usage: usage, isDown: true, time: .milliseconds(ms)))
}

private func up(_ usage: HIDUsage, at ms: Int, on device: Device = .builtIn) -> Step {
    .key(KeyEvent(device: device, usage: usage, isDown: false, time: .milliseconds(ms)))
}

private func down(_ key: Key, at ms: Int, on device: Device = .builtIn) -> Step {
    down(key.usage, at: ms, on: device)
}

private func up(_ key: Key, at ms: Int, on device: Device = .builtIn) -> Step {
    up(key.usage, at: ms, on: device)
}

/// Feeds the steps in order and returns the indexes of the steps that completed the gesture.
private func firings(of trigger: Trigger, _ steps: [Step]) -> [Int] {
    var recognizer = TriggerRecognizer(trigger)
    return steps.indices.filter { index in
        switch steps[index] {
        case .key(let event): recognizer.handle(event)
        case .tick(let time): recognizer.advance(to: time)
        }
    }
}

@Test func doubleTapFiresOnDownUpDownUpWithinTheWindow() {
    let steps = [down(.fn, at: 0), up(.fn, at: 80), down(.fn, at: 200), up(.fn, at: 280)]

    #expect(firings(of: fnDoubleTap, steps) == [3])
}

@Test func doubleTapDoesNotFireWhenTheSecondDownIsPastTheWindow() {
    let steps = [down(.fn, at: 0), up(.fn, at: 80), down(.fn, at: 401), up(.fn, at: 480)]

    #expect(firings(of: fnDoubleTap, steps) == [])
}

@Test func doubleTapDoesNotFireWhenAnotherKeyIsPressedInBetween() {
    let steps = [
        down(.fn, at: 0), up(.fn, at: 80),
        down(letterA, at: 120), up(letterA, at: 150),
        down(.fn, at: 200), up(.fn, at: 280),
    ]

    #expect(firings(of: fnDoubleTap, steps) == [])
}

@Test func doubleTapDoesNotFireOnASingleTap() {
    #expect(firings(of: fnDoubleTap, [down(.fn, at: 0), up(.fn, at: 80)]) == [])
}

@Test func doubleTapDoesNotFireOnAHeldKey() {
    #expect(firings(of: fnDoubleTap, [down(.fn, at: 0), up(.fn, at: 2000)]) == [])
}

@Test func doubleTapDoesNotCountAReleaseThatArrivesBeforeAnyPress() {
    // The release of a key held when observation started arrives on its own.
    let steps = [up(.fn, at: 0), down(.fn, at: 100), up(.fn, at: 150)]

    #expect(firings(of: fnDoubleTap, steps) == [])
}

@Test func doubleTapDoesNotFireForInputFromTheOtherDevice() {
    let steps = [
        down(.fn, at: 0, on: .external), up(.fn, at: 80, on: .external),
        down(.fn, at: 200, on: .external), up(.fn, at: 280, on: .external),
    ]

    #expect(firings(of: fnDoubleTap, steps) == [])
}

@Test func doubleTapStartsOverFromASecondDownPastTheWindow() {
    let steps = [
        down(.fn, at: 0), up(.fn, at: 80),
        down(.fn, at: 401), up(.fn, at: 450),
        down(.fn, at: 600), up(.fn, at: 650),
    ]

    #expect(firings(of: fnDoubleTap, steps) == [5])
}

@Test func doubleTapIgnoresReleasesOfOtherKeys() {
    // The built-in keyboard reports a release of usage 0x01 (ErrorRollOver) after almost every key.
    let errorRollOver = HIDUsage(page: 0x07, usage: 0x01)
    let steps = [
        down(.fn, at: 0), up(errorRollOver, at: 1),
        up(.fn, at: 80), up(errorRollOver, at: 81),
        down(.fn, at: 200), up(errorRollOver, at: 201),
        up(.fn, at: 280),
    ]

    #expect(firings(of: fnDoubleTap, steps) == [6])
}

@Test func holdFiresWhenAllKeysStayDownForTheDuration() {
    let steps = [
        down(.leftShift, at: 0, on: .external), down(.rightShift, at: 50, on: .external),
        .tick(.milliseconds(1049)), .tick(.milliseconds(1050)),
    ]

    #expect(firings(of: shiftsHeld, steps) == [3])
}

@Test func holdDoesNotFireWhenAKeyIsReleasedEarly() {
    let steps = [
        down(.leftShift, at: 0, on: .external), down(.rightShift, at: 50, on: .external),
        up(.rightShift, at: 500, on: .external),
        .tick(.milliseconds(2000)),
    ]

    #expect(firings(of: shiftsHeld, steps) == [])
}

@Test func holdDoesNotFireWhenAnotherKeyIsPressedMeanwhile() {
    let steps = [
        down(.leftShift, at: 0, on: .external), down(.rightShift, at: 50, on: .external),
        down(letterA, at: 300, on: .external),
        .tick(.milliseconds(2000)),
    ]

    #expect(firings(of: shiftsHeld, steps) == [])
}

@Test func holdFiresOnlyOnceWhileTheKeysStayDown() {
    let steps = [
        down(.leftShift, at: 0, on: .external), down(.rightShift, at: 50, on: .external),
        .tick(.milliseconds(1050)), .tick(.milliseconds(3000)),
    ]

    #expect(firings(of: shiftsHeld, steps) == [2])
}

@Test func holdDoesNotFireAfterAnInterruptionUntilTheKeysArePressedAgain() {
    let steps = [
        down(.leftShift, at: 0, on: .external), down(.rightShift, at: 50, on: .external),
        down(letterA, at: 300, on: .external), up(letterA, at: 350, on: .external),
        .tick(.milliseconds(2000)),
        up(.rightShift, at: 2100, on: .external), down(.rightShift, at: 2200, on: .external),
        .tick(.milliseconds(3199)), .tick(.milliseconds(3200)),
    ]

    #expect(firings(of: shiftsHeld, steps) == [8])
}

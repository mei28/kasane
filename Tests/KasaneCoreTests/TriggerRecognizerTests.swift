import KasaneCore
import Testing

private let fnDoubleTap = Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))
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

private let fnTripleTap = Trigger(device: .builtIn, gesture: .tap(.fn, count: 3, within: .milliseconds(600)))

@Test func tripleTapFiresOnTheThirdReleaseWithinTheWindow() {
    let steps = [
        down(.fn, at: 0), up(.fn, at: 50),
        down(.fn, at: 150), up(.fn, at: 200),
        down(.fn, at: 300), up(.fn, at: 350),
    ]

    #expect(firings(of: fnTripleTap, steps) == [5])
}

@Test func tripleTapDoesNotFireWhenTheThirdDownIsPastTheWindow() {
    let steps = [
        down(.fn, at: 0), up(.fn, at: 50),
        down(.fn, at: 150), up(.fn, at: 200),
        down(.fn, at: 601), up(.fn, at: 650),
    ]

    #expect(firings(of: fnTripleTap, steps) == [])
}

@Test func tripleTapStartsOverFromADownPastTheWindow() {
    let steps = [
        down(.fn, at: 0), up(.fn, at: 50),
        down(.fn, at: 150), up(.fn, at: 200),
        down(.fn, at: 601), up(.fn, at: 650),
        down(.fn, at: 700), up(.fn, at: 750),
        down(.fn, at: 800), up(.fn, at: 850),
    ]

    #expect(firings(of: fnTripleTap, steps) == [9])
}

// MARK: - Shortcuts

private let commandK = Trigger(device: .external, gesture: .shortcut([.command], .k))

private func down(_ key: ShortcutKey, at ms: Int, on device: Device = .external) -> Step {
    down(key.usage, at: ms, on: device)
}

private func up(_ key: ShortcutKey, at ms: Int, on device: Device = .external) -> Step {
    up(key.usage, at: ms, on: device)
}

@Test func shortcutFiresWhenTheLastKeyIsReleased() {
    let steps = [
        down(.leftCommand, at: 0, on: .external), down(.k, at: 50), up(.k, at: 120),
        up(.leftCommand, at: 200, on: .external),
    ]

    #expect(firings(of: commandK, steps) == [3])
}

@Test func shortcutDoesNotFireWithoutItsModifiers() {
    #expect(firings(of: commandK, [down(.k, at: 0), up(.k, at: 80)]) == [])
}

@Test func shortcutDoesNotFireWithAnExtraModifier() {
    let steps = [
        down(.leftCommand, at: 0, on: .external), down(.leftShift, at: 10, on: .external), down(.k, at: 50),
        up(.k, at: 120), up(.leftShift, at: 150, on: .external), up(.leftCommand, at: 200, on: .external),
    ]

    #expect(firings(of: commandK, steps) == [])
}

@Test func shortcutAcceptsEitherSideOfAModifier() {
    let steps = [
        down(.rightCommand, at: 0, on: .external), down(.k, at: 50), up(.k, at: 120),
        up(.rightCommand, at: 200, on: .external),
    ]

    #expect(firings(of: commandK, steps) == [3])
}

@Test func shortcutAcceptsModifiersPressedInEitherOrder() {
    let optionCommandK = Trigger(device: .external, gesture: .shortcut([.option, .command], .k))
    let steps = [
        down(.leftOption, at: 0, on: .external), down(.leftCommand, at: 10, on: .external), down(.k, at: 50),
        up(.k, at: 120), up(.leftCommand, at: 150, on: .external), up(.leftOption, at: 200, on: .external),
    ]
    let reversed = [
        down(.leftCommand, at: 0, on: .external), down(.leftOption, at: 10, on: .external), down(.k, at: 50),
        up(.k, at: 120), up(.leftOption, at: 150, on: .external), up(.leftCommand, at: 200, on: .external),
    ]

    #expect(firings(of: optionCommandK, steps) == [5])
    #expect(firings(of: optionCommandK, reversed) == [5])
}

@Test func shortcutDoesNotFireWithFnHeld() {
    let steps = [
        down(.fn, at: 0, on: .external), down(.leftCommand, at: 10, on: .external), down(.k, at: 50),
        up(.k, at: 120), up(.leftCommand, at: 150, on: .external), up(.fn, at: 200, on: .external),
    ]

    #expect(firings(of: commandK, steps) == [])
}

@Test(arguments: [(999, [3]), (1000, [])])
func shortcutFiresOnlyWhenItsKeyIsDownUnderASecond(_ heldMs: Int, _ expected: [Int]) {
    let steps = [
        down(.leftCommand, at: 0, on: .external), down(.k, at: 50), up(.k, at: 50 + heldMs),
        up(.leftCommand, at: 100 + heldMs, on: .external),
    ]

    #expect(firings(of: commandK, steps) == expected)
}

@Test func anotherKeyCancelsAShortcut() {
    let steps = [
        down(.leftCommand, at: 0, on: .external), down(.k, at: 50), down(.j, at: 60), up(.j, at: 90),
        up(.k, at: 120), up(.leftCommand, at: 200, on: .external),
    ]

    #expect(firings(of: commandK, steps) == [])
}

@Test func aModifierPressedAfterTheKeyCancelsAShortcut() {
    let steps = [
        down(.leftCommand, at: 0, on: .external), down(.k, at: 50), down(.leftShift, at: 70, on: .external),
        up(.k, at: 120), up(.leftShift, at: 150, on: .external), up(.leftCommand, at: 200, on: .external),
    ]

    #expect(firings(of: commandK, steps) == [])
}

@Test func shortcutFiresWhenTheModifierIsReleasedBeforeTheKey() {
    let steps = [
        down(.leftCommand, at: 0, on: .external), down(.k, at: 50), up(.leftCommand, at: 90, on: .external),
        up(.k, at: 120),
    ]

    #expect(firings(of: commandK, steps) == [3])
}

@Test func releasesOfUsage1DoNotCancelAShortcut() {
    // The built-in keyboard sends a release of usage 0x01 after most keys.
    let rollover = HIDUsage(page: 0x07, usage: 0x01)
    let controlK = Trigger(device: .builtIn, gesture: .shortcut([.control], .k))
    let steps = [
        down(.leftControl, at: 0), up(rollover, at: 1), down(.k, at: 50, on: .builtIn), up(rollover, at: 51),
        up(.k, at: 120, on: .builtIn), up(rollover, at: 121), up(.leftControl, at: 200),
    ]

    #expect(firings(of: controlK, steps) == [6])
}

@Test func shortcutIgnoresAModifierHeldBeforeObservationStarted() {
    // Only the release of ⌘ is seen, so kasane cannot know it is down when K is pressed.
    let steps = [down(.k, at: 50), up(.k, at: 120), up(.leftCommand, at: 200, on: .external)]

    #expect(firings(of: commandK, steps) == [])
}

@Test func shortcutFiresAgainOnTheNextPress() {
    let once = [
        down(.leftCommand, at: 0, on: .external), down(.k, at: 50), up(.k, at: 120),
        up(.leftCommand, at: 200, on: .external),
    ]
    let twice = once + [
        down(.leftCommand, at: 1000, on: .external), down(.k, at: 1050), up(.k, at: 1120),
        up(.leftCommand, at: 1200, on: .external),
    ]

    #expect(firings(of: commandK, twice) == [3, 7])
}

@Test func shortcutIgnoresTheOtherKeyboard() {
    let steps = [
        down(.leftCommand, at: 0, on: .builtIn), down(.k, at: 50, on: .builtIn), up(.k, at: 120, on: .builtIn),
        up(.leftCommand, at: 200, on: .builtIn),
    ]

    #expect(firings(of: commandK, steps) == [])
}

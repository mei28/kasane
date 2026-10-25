import KasaneCore
import Testing

private func event(_ usage: HIDUsage, _ isDown: Bool, at ms: Int, on device: Device) -> KeyEvent {
    KeyEvent(device: device, usage: usage, isDown: isDown, time: .milliseconds(ms))
}

/// One press and release of `key`.
private func press(_ key: Key, _ downMs: Int, _ upMs: Int, on device: Device = .builtIn) -> [KeyEvent] {
    [event(key.usage, true, at: downMs, on: device), event(key.usage, false, at: upMs, on: device)]
}

private func recorded(_ events: [KeyEvent]) -> GestureRecorder {
    var recorder = GestureRecorder(startedAt: .zero)
    for event in events {
        recorder.record(event)
    }
    return recorder
}

@Test func tapsOfOneKeyBecomeATapWithTheMeasuredWindow() {
    // The presses span 300 ms; 1.5 times that, rounded up to 50 ms, is 450 ms.
    let recorder = recorded(press(.fn, 0, 50) + press(.fn, 150, 200) + press(.fn, 300, 350))

    #expect(recorder.result() == .success(Trigger(device: .builtIn, gesture: .tap(.fn, count: 3, within: .milliseconds(450)))))
}

@Test func keysHeldTogetherBecomeAHold() {
    // Both are down from 50 ms to 1280 ms: 1230 ms, rounded down to 1200 ms.
    let recorder = recorded([
        event(Key.leftShift.usage, true, at: 0, on: .external),
        event(Key.rightShift.usage, true, at: 50, on: .external),
        event(Key.leftShift.usage, false, at: 1280, on: .external),
        event(Key.rightShift.usage, false, at: 1300, on: .external),
    ])

    #expect(
        recorder.result()
            == .success(Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1200)))))
}

@Test func oneKeyHeldLongBecomesAHoldOfThatKey() {
    let recorder = recorded(press(.rightCommand, 0, 900, on: .external))

    #expect(recorder.result() == .success(Trigger(device: .external, gesture: .hold([.rightCommand], for: .milliseconds(900)))))
}

@Test func rejectsARecordingWithNoPresses() {
    #expect(recorded([]).result() == .failure(.nothingRecorded))
}

@Test func rejectsASingleTap() {
    #expect(recorded(press(.fn, 0, 50)).result() == .failure(.singleTap))
}

@Test func rejectsMoreThanFiveTaps() {
    let taps = (0..<6).flatMap { press(.fn, $0 * 100, $0 * 100 + 50) }

    #expect(recorded(taps).result() == .failure(.tooManyTaps(6)))
}

@Test func rejectsARecordingFromTwoDevices() {
    let recorder = recorded(press(.fn, 0, 50) + press(.fn, 150, 200, on: .external))

    #expect(recorder.result() == .failure(.multipleDevices))
}

@Test func rejectsAKeyKasaneHasNoNameFor() {
    let capsLock = HIDUsage(page: 0x07, usage: 0x39)
    let recorder = recorded([
        event(capsLock, true, at: 0, on: .builtIn), event(capsLock, false, at: 50, on: .builtIn),
        event(capsLock, true, at: 150, on: .builtIn), event(capsLock, false, at: 200, on: .builtIn),
    ])

    #expect(recorder.result() == .failure(.unsupportedKey(capsLock)))
}

@Test func rejectsTapsOfTwoKeys() {
    let recorder = recorded(press(.fn, 0, 50) + press(.leftShift, 150, 200))

    #expect(recorder.result() == .failure(.tapsOnSeveralKeys))
}

@Test func rejectsAHoldShorterThanHalfASecond() {
    // Both are down together only from 50 ms to 300 ms.
    let recorder = recorded([
        event(Key.leftShift.usage, true, at: 0, on: .external),
        event(Key.rightShift.usage, true, at: 50, on: .external),
        event(Key.leftShift.usage, false, at: 300, on: .external),
        event(Key.rightShift.usage, false, at: 320, on: .external),
    ])

    #expect(recorder.result() == .failure(.holdTooShort))
}

@Test func rejectsKeysThatWereNeverAllDownTogether() {
    // leftShift is released before rightCommand goes down.
    let recorder = recorded([
        event(Key.leftShift.usage, true, at: 0, on: .external),
        event(Key.rightShift.usage, true, at: 100, on: .external),
        event(Key.leftShift.usage, false, at: 600, on: .external),
        event(Key.rightCommand.usage, true, at: 650, on: .external),
        event(Key.rightShift.usage, false, at: 1200, on: .external),
        event(Key.rightCommand.usage, false, at: 1300, on: .external),
    ])

    #expect(recorder.result() == .failure(.notHeldTogether))
}

@Test func rejectsAKeyStillDownWhenTheRecordingEnds() {
    let recorder = recorded([event(Key.rightCommand.usage, true, at: 0, on: .external)])

    #expect(recorder.result() == .failure(.keyStillDown))
}

@Test func ignoresAReleaseBeforeAnyPress() {
    // A key held when the recording started is released during it.
    let recorder = recorded([event(Key.fn.usage, false, at: 0, on: .builtIn)] + press(.fn, 100, 150) + press(.fn, 250, 300))

    #expect(recorder.result() == .success(Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(250)))))
}

@Test func finishesOneSecondAfterTheLastReleaseWithNoKeyDown() {
    let recorder = recorded(press(.fn, 0, 50) + press(.fn, 150, 200))

    #expect(!recorder.isFinished(at: .milliseconds(1199)))
    #expect(recorder.isFinished(at: .milliseconds(1200)))
}

@Test func finishesFifteenSecondsAfterItStartedEvenWithAKeyDown() {
    let recorder = recorded([event(Key.rightCommand.usage, true, at: 0, on: .external)])

    #expect(!recorder.isFinished(at: .milliseconds(14_999)))
    #expect(recorder.isFinished(at: .seconds(15)))
}

// MARK: - Shortcuts

/// One press and release of a shortcut key.
private func press(_ key: ShortcutKey, _ downMs: Int, _ upMs: Int, on device: Device = .external) -> [KeyEvent] {
    [event(key.usage, true, at: downMs, on: device), event(key.usage, false, at: upMs, on: device)]
}

private func down(_ key: Key, at ms: Int, on device: Device = .external) -> KeyEvent {
    event(key.usage, true, at: ms, on: device)
}

private func up(_ key: Key, at ms: Int, on device: Device = .external) -> KeyEvent {
    event(key.usage, false, at: ms, on: device)
}

@Test func aKeyPressedWithAModifierBecomesAShortcut() {
    let recorder = recorded([down(.leftCommand, at: 0)] + press(.k, 50, 120) + [up(.leftCommand, at: 200)])

    #expect(recorder.result() == .success(Trigger(device: .external, gesture: .shortcut([.command], .k))))
}

@Test func modifiersFromEitherSideJoinTheShortcut() {
    let recorder = recorded(
        [down(.rightOption, at: 0), down(.leftCommand, at: 10)] + press(.k, 50, 120)
            + [up(.leftCommand, at: 150), up(.rightOption, at: 200)])

    #expect(recorder.result() == .success(Trigger(device: .external, gesture: .shortcut([.option, .command], .k))))
}

@Test func aKeyAloneBecomesAShortcutWithoutModifiers() {
    // Config.validate rejects it, so the rule that a shortcut needs ⌃ or ⌘ lives in one place.
    let recorder = recorded(press(.k, 0, 80))

    #expect(recorder.result() == .success(Trigger(device: .external, gesture: .shortcut([], .k))))
}

@Test func rejectsFnInAShortcut() {
    let recorder = recorded([down(.fn, at: 0)] + press(.k, 50, 120) + [up(.fn, at: 200)])

    #expect(recorder.result() == .failure(.fnInShortcut))
}

@Test func rejectsSeveralShortcutKeys() {
    let twice = recorded([down(.leftCommand, at: 0)] + press(.k, 50, 120) + press(.k, 150, 220) + [up(.leftCommand, at: 300)])
    let two = recorded([down(.leftCommand, at: 0)] + press(.k, 50, 120) + press(.j, 150, 220) + [up(.leftCommand, at: 300)])

    #expect(twice.result() == .failure(.severalKeys))
    #expect(two.result() == .failure(.severalKeys))
}

@Test func rejectsAModifierReleasedBeforeTheKey() {
    let recorder = recorded(
        [down(.leftShift, at: 0), up(.leftShift, at: 40), down(.leftCommand, at: 50)] + press(.k, 100, 150)
            + [up(.leftCommand, at: 200)])

    #expect(recorder.result() == .failure(.notHeldTogether))
}

@Test func rejectsAModifierPressedAfterTheKey() {
    let recorder = recorded(
        [down(.leftCommand, at: 0), event(ShortcutKey.k.usage, true, at: 50, on: .external), down(.leftShift, at: 80)]
            + [event(ShortcutKey.k.usage, false, at: 120, on: .external), up(.leftShift, at: 150), up(.leftCommand, at: 200)])

    #expect(recorder.result() == .failure(.notHeldTogether))
}

@Test func rejectsAShortcutWithAKeyKasaneHasNoNameFor() {
    let capsLock = HIDUsage(page: 0x07, usage: 0x39)
    let recorder = recorded(
        [down(.leftCommand, at: 0), event(capsLock, true, at: 50, on: .external), event(capsLock, false, at: 120, on: .external),
         up(.leftCommand, at: 200)])

    #expect(recorder.result() == .failure(.unsupportedKey(capsLock)))
}

@Test func ignoresUsage1ReleasesInAShortcut() {
    // The built-in keyboard sends a release of usage 0x01 after most keys.
    let rollover = HIDUsage(page: 0x07, usage: 0x01)
    let recorder = recorded([
        down(.leftControl, at: 0, on: .builtIn), event(rollover, false, at: 1, on: .builtIn),
        event(ShortcutKey.k.usage, true, at: 50, on: .builtIn), event(rollover, false, at: 51, on: .builtIn),
        event(ShortcutKey.k.usage, false, at: 120, on: .builtIn), up(.leftControl, at: 200, on: .builtIn),
    ])

    #expect(recorder.result() == .success(Trigger(device: .builtIn, gesture: .shortcut([.control], .k))))
}

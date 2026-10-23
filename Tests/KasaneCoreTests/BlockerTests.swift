import KasaneCore
import Testing

private let safe = Safety(externalKeyboardConnected: true, screenLocked: false, onConsole: true, asleep: false)

private func safe(but change: (inout Safety) -> Void) -> Safety {
    var safety = safe
    change(&safety)
    return safety
}

/// Each safety condition broken on its own: lock, leaving the console, sleep, last external keyboard gone.
private let unsafeStates = [
    safe { $0.screenLocked = true },
    safe { $0.onConsole = false },
    safe { $0.asleep = true },
    safe { $0.externalKeyboardConnected = false },
]

@Test func startsOff() {
    #expect(!Blocker(safety: safe).isOn)
}

@Test func onTriggerTurnsOnAndAsksToSeizeAndLightTheLEDWhenSafe() {
    var blocker = Blocker(safety: safe)

    #expect(blocker.onTrigger() == [.seize, .ledOn])
    #expect(blocker.isOn)
}

@Test(arguments: unsafeStates)
func refusesTheOnTriggerWhenUnsafe(_ safety: Safety) {
    var blocker = Blocker(safety: safety)

    #expect(blocker.onTrigger() == [])
    #expect(!blocker.isOn)
}

@Test func offTriggerTurnsOffAndAsksToTurnTheLEDOffAndRelease() {
    var blocker = Blocker(safety: safe)
    _ = blocker.onTrigger()

    #expect(blocker.offTrigger() == [.ledOff, .release])
    #expect(!blocker.isOn)
}

@Test func offTriggerWhileOffDoesNothing() {
    var blocker = Blocker(safety: safe)

    #expect(blocker.offTrigger() == [])
    #expect(!blocker.isOn)
}

@Test func onTriggerWhileOnDoesNothing() {
    var blocker = Blocker(safety: safe)
    _ = blocker.onTrigger()

    #expect(blocker.onTrigger() == [])
    #expect(blocker.isOn)
}

@Test(arguments: unsafeStates)
func losingASafetyConditionTurnsOff(_ safety: Safety) {
    var blocker = Blocker(safety: safe)
    _ = blocker.onTrigger()

    #expect(blocker.update(safety) == [.ledOff, .release])
    #expect(!blocker.isOn)
}

@Test(arguments: unsafeStates)
func staysOffWhenTheSafetyConditionComesBack(_ safety: Safety) {
    var blocker = Blocker(safety: safe)
    _ = blocker.onTrigger()
    _ = blocker.update(safety)

    #expect(blocker.update(safe) == [])
    #expect(!blocker.isOn)
}

@Test(arguments: unsafeStates)
func onTriggerChecksTheLatestSafetyConditions(_ safety: Safety) {
    var blocker = Blocker(safety: safe)
    _ = blocker.update(safety)

    #expect(blocker.onTrigger() == [])
    #expect(!blocker.isOn)
}

@Test func losingTheSeizeTurnsOff() {
    var blocker = Blocker(safety: safe)
    _ = blocker.onTrigger()

    blocker.lostSeize()

    #expect(!blocker.isOn)
}

@Test func aGestureInBothListsTurnsOnWhileOff() {
    var blocker = Blocker(safety: safe)

    #expect(blocker.triggered(on: true, off: true) == [.seize, .ledOn])
    #expect(blocker.isOn)
}

@Test func aGestureInBothListsTurnsOffWhileOn() {
    var blocker = Blocker(safety: safe)
    _ = blocker.onTrigger()

    #expect(blocker.triggered(on: true, off: true) == [.ledOff, .release])
    #expect(!blocker.isOn)
}

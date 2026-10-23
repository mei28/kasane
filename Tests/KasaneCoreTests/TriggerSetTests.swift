import KasaneCore
import Testing

private let fnToggle = Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))
private let shiftsHeld = Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1000)))
private let config = Config(on: [fnToggle], off: [shiftsHeld, fnToggle])

private func event(_ key: Key, _ isDown: Bool, at ms: Int, on device: Device = .builtIn) -> KeyEvent {
    KeyEvent(device: device, usage: key.usage, isDown: isDown, time: .milliseconds(ms))
}

@Test func reportsWhichSideFiredForAnEvent() {
    var triggers = TriggerSet(config)

    _ = triggers.handle(event(.fn, true, at: 0))
    _ = triggers.handle(event(.fn, false, at: 50))
    _ = triggers.handle(event(.fn, true, at: 150))

    #expect(triggers.handle(event(.fn, false, at: 200)) == Fired(on: true, off: true))
}

@Test func reportsHoldFiringsOnAdvance() {
    var triggers = TriggerSet(config)
    _ = triggers.handle(event(.leftShift, true, at: 0, on: .external))
    _ = triggers.handle(event(.rightShift, true, at: 50, on: .external))

    #expect(triggers.advance(to: .milliseconds(1050)) == Fired(on: false, off: true))
}

@Test func resetForgetsPartialProgress() {
    var triggers = TriggerSet(config)
    _ = triggers.handle(event(.fn, true, at: 0))
    _ = triggers.handle(event(.fn, false, at: 50))

    triggers.reset()
    _ = triggers.handle(event(.fn, true, at: 150))

    #expect(triggers.handle(event(.fn, false, at: 200)) == Fired(on: false, off: false))
}

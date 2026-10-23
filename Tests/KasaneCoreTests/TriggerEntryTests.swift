import KasaneCore
import Testing

private let fnToggle = Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))
private let commandOn = Trigger(device: .external, gesture: .tap(.rightCommand, count: 3, within: .milliseconds(600)))
private let shiftsOff = Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1000)))

@Test func entriesGiveEachTriggerItsRole() {
    let config = Config(on: [fnToggle, commandOn], off: [shiftsOff, fnToggle])

    #expect(
        config.entries == [
            TriggerEntry(trigger: fnToggle, role: .toggle),
            TriggerEntry(trigger: commandOn, role: .on),
            TriggerEntry(trigger: shiftsOff, role: .off),
        ])
}

@Test func aConfigBuiltFromEntriesListsTogglesUnderBoth() {
    let entries = [
        TriggerEntry(trigger: fnToggle, role: .toggle),
        TriggerEntry(trigger: commandOn, role: .on),
        TriggerEntry(trigger: shiftsOff, role: .off),
    ]

    #expect(Config(entries: entries, paused: true) == Config(on: [fnToggle, commandOn], off: [fnToggle, shiftsOff], paused: true))
}

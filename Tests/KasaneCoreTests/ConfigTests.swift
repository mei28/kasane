import Foundation
import KasaneCore
import Testing

private let fnTwice = #"{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": 2, "withinMs": 400 }"#
private let shiftsHeld = #"{ "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 }"#

/// A valid config with one part replaced, to test each validation rule on its own. A nil
/// `paused` leaves the field out.
private func configJSON(toggle: [String] = [fnTwice], externalOff: [String] = [shiftsHeld], paused: Bool? = false) -> Data {
    func list(_ triggers: [String]) -> String { "[\(triggers.joined(separator: ", "))]" }
    var fields = [#""toggle": \#(list(toggle))"#, #""externalOff": \#(list(externalOff))"#]
    if let paused { fields.append(#""paused": \#(paused)"#) }
    return Data("{ \(fields.joined(separator: ", ")) }".utf8)
}

@Test func rejectsTheOnOffFormat() {
    let onOff = #"""
        {
          "on": [{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": 2, "withinMs": 400 }],
          "off": [{ "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 }],
          "paused": false
        }
        """#
    #expect(throws: DecodingError.self) {
        try Config.parse(Data(onOff.utf8))
    }
}

@Test func parsesOneTriggerPerAction() throws {
    let config = try Config.parse(
        configJSON(
            toggle: [#"{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": 3, "withinMs": 600 }"#],
            externalOff: [#"{ "device": "external", "gesture": "tap", "key": "rightCommand", "count": 2, "withinMs": 400 }"#]))

    #expect(
        config
            == Config(
                toggle: [Trigger(device: .builtIn, gesture: .tap(.fn, count: 3, within: .milliseconds(600)))],
                externalOff: [Trigger(device: .external, gesture: .tap(.rightCommand, count: 2, within: .milliseconds(400)))]))
}

@Test func encodingThenParsingGivesTheSameConfig() throws {
    var config = try Config.parse(configJSON())
    config.paused = true

    #expect(try Config.parse(config.encoded()) == config)
}

@Test func rejectsAConfigWithoutPaused() {
    #expect(throws: DecodingError.self) {
        try Config.parse(configJSON(paused: nil))
    }
}

@Test func theDefaultConfigTogglesWithFnAndTurnsOffWithBothShiftsHeld() throws {
    #expect(
        Config.default
            == Config(
                toggle: [Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))],
                externalOff: [
                    Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1000)))
                ]))
    #expect(try Config.parse(Config.default.encoded()) == Config.default)
}

@Test func rejectsAnExternalOffTriggerOnTheBuiltInKeyboard() {
    #expect(throws: ConfigError.externalOffOnBuiltIn) {
        try Config.parse(configJSON(externalOff: [fnTwice]))
    }
}

@Test func rejectsAToggleHeldOnTheBuiltInKeyboard() {
    #expect(throws: ConfigError.holdOnBuiltIn) {
        try Config.parse(configJSON(toggle: [#"{ "device": "builtIn", "gesture": "hold", "keys": ["fn"], "forMs": 1000 }"#]))
    }
}

@Test func acceptsAToggleHeldOnTheExternalKeyboard() throws {
    let toggle = #"{ "device": "external", "gesture": "hold", "keys": ["leftCommand", "rightCommand"], "forMs": 1000 }"#

    #expect(throws: Never.self) { try Config.parse(configJSON(toggle: [toggle])) }
}

@Test func reportsAnExternalOffHoldOnTheBuiltInKeyboardAsTheWrongKeyboard() {
    #expect(throws: ConfigError.externalOffOnBuiltIn) {
        try Config.parse(configJSON(externalOff: [#"{ "device": "builtIn", "gesture": "hold", "keys": ["fn"], "forMs": 1000 }"#]))
    }
}

private func fnTaps(_ count: Int) -> String {
    #"{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": \#(count), "withinMs": 400 }"#
}

private func rightCommandTaps(_ count: Int, on device: String = "external") -> String {
    #"{ "device": "\#(device)", "gesture": "tap", "key": "rightCommand", "count": \#(count), "withinMs": 400 }"#
}

@Test(arguments: [1, 6])
func rejectsAToggleTapCountOutsideTwoToFive(_ count: Int) {
    #expect(throws: ConfigError.tapCountOutOfRange(count)) {
        try Config.parse(configJSON(toggle: [fnTaps(count)]))
    }
}

@Test(arguments: [1, 6])
func rejectsAnExternalOffTapCountOutsideTwoToFive(_ count: Int) {
    #expect(throws: ConfigError.tapCountOutOfRange(count)) {
        try Config.parse(configJSON(externalOff: [rightCommandTaps(count)]))
    }
}

@Test(arguments: [2, 5])
func acceptsTwoToFiveTaps(_ count: Int) {
    #expect(throws: Never.self) {
        try Config.parse(configJSON(toggle: [fnTaps(count)], externalOff: [rightCommandTaps(count)]))
    }
}

@Test func rejectsTapsOnTheSameKeyWithDifferentCounts() {
    // Three taps to turn OFF would turn OFF and ON again: the toggle fires at the second tap.
    #expect(throws: ConfigError.conflictingTapCounts(.rightCommand, .external)) {
        try Config.parse(configJSON(toggle: [rightCommandTaps(2)], externalOff: [rightCommandTaps(3)]))
    }
}

@Test func rejectsTheSameTapInBothActionsAsADuplicate() {
    #expect(throws: ConfigError.duplicateTrigger) {
        try Config.parse(configJSON(toggle: [rightCommandTaps(2)], externalOff: [shiftsHeld, rightCommandTaps(2)]))
    }
}

@Test func acceptsDifferentCountsOnTheSameKeyOfDifferentKeyboards() {
    #expect(throws: Never.self) {
        try Config.parse(configJSON(toggle: [rightCommandTaps(2, on: "builtIn")], externalOff: [rightCommandTaps(3)]))
    }
}

@Test func rejectsAnUnknownKeyName() {
    #expect(throws: ConfigError.unknownKey("capsLok")) {
        try Config.parse(configJSON(toggle: [#"{ "device": "builtIn", "gesture": "tap", "key": "capsLok", "count": 2, "withinMs": 400 }"#]))
    }
}

@Test func theExampleConfigFileIsTheDefault() throws {
    let example = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "../../examples/config.json").standardized

    #expect(try Config.parse(Data(contentsOf: example)) == Config.default)
}

@Test func rejectsATriggerThatIsNotInAList() {
    let single = Data(#"{ "toggle": \#(fnTwice), "externalOff": [\#(shiftsHeld)], "paused": false }"#.utf8)

    #expect(throws: DecodingError.self) {
        try Config.parse(single)
    }
}

@Test func acceptsNoToggleTriggers() {
    // The menu can still block the built-in keyboard.
    #expect(throws: Never.self) { try Config.parse(configJSON(toggle: [])) }
}

@Test func rejectsNoExternalOffTriggers() {
    #expect(throws: ConfigError.noExternalOffTrigger) {
        try Config.parse(configJSON(externalOff: []))
    }
}

@Test func rejectsAnyExternalOffTriggerOnTheBuiltInKeyboard() {
    #expect(throws: ConfigError.externalOffOnBuiltIn) {
        try Config.parse(configJSON(externalOff: [shiftsHeld, fnTwice]))
    }
}

@Test func rejectsAnyToggleHeldOnTheBuiltInKeyboard() {
    let fnHeld = #"{ "device": "builtIn", "gesture": "hold", "keys": ["fn"], "forMs": 1000 }"#

    #expect(throws: ConfigError.holdOnBuiltIn) {
        try Config.parse(configJSON(toggle: [fnTwice, fnHeld]))
    }
}

@Test func rejectsAnyToggleTapCountOutsideTwoToFive() {
    #expect(throws: ConfigError.tapCountOutOfRange(6)) {
        try Config.parse(configJSON(toggle: [fnTwice, rightCommandTaps(6, on: "builtIn")]))
    }
}

@Test func rejectsDifferentTapCountsWithinOneAction() {
    #expect(throws: ConfigError.conflictingTapCounts(.fn, .builtIn)) {
        try Config.parse(configJSON(toggle: [fnTwice, fnTaps(3)]))
    }
}

@Test func rejectsDifferentTapCountsAcrossActions() {
    #expect(throws: ConfigError.conflictingTapCounts(.rightCommand, .external)) {
        try Config.parse(configJSON(toggle: [fnTwice, rightCommandTaps(2)], externalOff: [rightCommandTaps(3)]))
    }
}

@Test func rejectsTapsThatDifferOnlyInTimeAsDuplicates() {
    let slowerFnTwice = #"{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": 2, "withinMs": 650 }"#

    #expect(throws: ConfigError.duplicateTrigger) {
        try Config.parse(configJSON(toggle: [fnTwice, slowerFnTwice]))
    }
}

@Test func rejectsHoldsThatDifferOnlyInTimeAsDuplicates() {
    let shiftsHeldLonger = #"{ "device": "external", "gesture": "hold", "keys": ["rightShift", "leftShift"], "forMs": 2000 }"#

    #expect(throws: ConfigError.duplicateTrigger) {
        try Config.parse(configJSON(externalOff: [shiftsHeld, shiftsHeldLonger]))
    }
}

@Test func acceptsTheSameTapOnBothKeyboards() {
    #expect(throws: Never.self) {
        try Config.parse(configJSON(toggle: [rightCommandTaps(2, on: "builtIn"), rightCommandTaps(2)]))
    }
}

private func shortcut(_ modifiers: [String], _ key: String, on device: String = "external") -> String {
    let names = modifiers.map { #""\#($0)""# }.joined(separator: ", ")
    return #"{ "device": "\#(device)", "gesture": "shortcut", "modifiers": [\#(names)], "key": "\#(key)" }"#
}

@Test func parsesAShortcut() throws {
    let config = try Config.parse(configJSON(externalOff: [shortcut(["option", "command"], "k")]))

    #expect(config.externalOff == [Trigger(device: .external, gesture: .shortcut([.option, .command], .k))])
}

@Test func writesModifiersInTheOrderMacOSShowsThem() throws {
    let config = try Config.parse(configJSON(externalOff: [shortcut(["command", "shift", "control", "option"], "k")]))
    let written = try JSONSerialization.jsonObject(with: config.encoded()) as? [String: Any]
    let externalOff = written?["externalOff"] as? [[String: Any]]

    #expect(externalOff?.first?["modifiers"] as? [String] == ["control", "option", "shift", "command"])
    #expect(try Config.parse(config.encoded()) == config)
}

@Test(arguments: [shortcut(["hyper"], "k"), shortcut(["command"], "f13")])
func rejectsUnknownNamesInAShortcut(_ trigger: String) {
    #expect(throws: ConfigError.self) {
        try Config.parse(configJSON(externalOff: [trigger]))
    }
}

@Test(arguments: [[], ["shift"], ["option"], ["option", "shift"]])
func rejectsAShortcutWithoutControlOrCommand(_ modifiers: [String]) {
    // ⇧K types a capital and ⌥← moves by word: both fire in ordinary typing.
    #expect(throws: ConfigError.shortcutNeedsCommandOrControl) {
        try Config.parse(configJSON(externalOff: [shiftsHeld, shortcut(modifiers, "k")]))
    }
}

@Test(arguments: [["control"], ["command"], ["control", "shift"]])
func acceptsAShortcutWithControlOrCommand(_ modifiers: [String]) {
    #expect(throws: Never.self) {
        try Config.parse(configJSON(externalOff: [shiftsHeld, shortcut(modifiers, "k")]))
    }
}

@Test func acceptsAShortcutOnTheBuiltInKeyboardToToggle() {
    #expect(throws: Never.self) {
        try Config.parse(configJSON(toggle: [fnTwice, shortcut(["control"], "k", on: "builtIn")]))
    }
}

@Test func rejectsAShortcutOnTheBuiltInKeyboardToTurnOff() {
    #expect(throws: ConfigError.externalOffOnBuiltIn) {
        try Config.parse(configJSON(externalOff: [shiftsHeld, shortcut(["control"], "k", on: "builtIn")]))
    }
}

@Test func acceptsTheSameShortcutOnBothKeyboards() {
    #expect(throws: Never.self) {
        try Config.parse(
            configJSON(toggle: [shortcut(["control"], "k", on: "builtIn"), shortcut(["control"], "k")]))
    }
}

@Test func rejectsTheSameShortcutTwiceOnOneKeyboard() {
    #expect(throws: ConfigError.duplicateTrigger) {
        try Config.parse(
            configJSON(toggle: [shortcut(["control"], "k")], externalOff: [shiftsHeld, shortcut(["control"], "k")]))
    }
}

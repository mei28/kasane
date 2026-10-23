import Foundation
import KasaneCore
import Testing

private let exampleConfig = """
    {
      "on": [
        { "device": "builtIn", "gesture": "tap", "key": "fn", "count": 2, "withinMs": 400 }
      ],
      "off": [
        { "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 },
        { "device": "external", "gesture": "tap", "key": "rightCommand", "count": 2, "withinMs": 400 }
      ]
    }
    """

/// A valid config with one part replaced, to test each validation rule on its own.
private func configJSON(
    on: String = #"[{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": 2, "withinMs": 400 }]"#,
    off: String = #"[{ "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 }]"#
) -> Data {
    Data(#"{ "on": \#(on), "off": \#(off) }"#.utf8)
}

@Test func acceptsTheExampleConfig() throws {
    let config = try Config.parse(Data(exampleConfig.utf8))

    #expect(
        config
            == Config(
                on: [Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))],
                off: [
                    Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1000))),
                    Trigger(device: .external, gesture: .tap(.rightCommand, count: 2, within: .milliseconds(400))),
                ]
            ))
}

@Test func rejectsAConfigWithoutAnExternalOffTrigger() {
    #expect(throws: ConfigError.noExternalOffTrigger) {
        try Config.parse(configJSON(off: "[]"))
    }
}

@Test func rejectsHoldOnTheBuiltInKeyboard() {
    #expect(throws: ConfigError.holdOnBuiltIn) {
        try Config.parse(configJSON(on: #"[{ "device": "builtIn", "gesture": "hold", "keys": ["fn"], "forMs": 1000 }]"#))
    }
}

@Test func acceptsAnOffTriggerOnTheBuiltInKeyboard() throws {
    let off = #"""
        [
          { "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 },
          { "device": "builtIn", "gesture": "tap", "key": "fn", "count": 2, "withinMs": 400 }
        ]
        """#
    let config = try Config.parse(configJSON(off: off))

    #expect(config.off.contains(Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))))
}

@Test func rejectsAnUnknownKeyName() {
    #expect(throws: ConfigError.unknownKey("capsLok")) {
        try Config.parse(configJSON(on: #"[{ "device": "builtIn", "gesture": "tap", "key": "capsLok", "count": 2, "withinMs": 400 }]"#))
    }
}

@Test func rejectsHoldOnTheBuiltInKeyboardInOff() {
    let off = #"""
        [
          { "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 },
          { "device": "builtIn", "gesture": "hold", "keys": ["fn"], "forMs": 1000 }
        ]
        """#
    #expect(throws: ConfigError.holdOnBuiltIn) {
        try Config.parse(configJSON(off: off))
    }
}

@Test(arguments: [1, 6])
func rejectsATapCountOutsideTwoToFive(_ count: Int) {
    #expect(throws: ConfigError.tapCountOutOfRange(count)) {
        try Config.parse(configJSON(on: #"[{ "device": "builtIn", "gesture": "tap", "key": "fn", "count": \#(count), "withinMs": 400 }]"#))
    }
}

@Test func rejectsTapsOnTheSameKeyWithDifferentCounts() {
    // With fn x2 to turn ON and fn x3 to turn OFF, three taps would turn ON at the second tap.
    let off = #"""
        [
          { "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 },
          { "device": "builtIn", "gesture": "tap", "key": "fn", "count": 3, "withinMs": 600 }
        ]
        """#
    #expect(throws: ConfigError.conflictingTapCounts(.fn, .builtIn)) {
        try Config.parse(configJSON(off: off))
    }
}

@Test func encodingThenParsingGivesTheSameConfig() throws {
    let config = try Config.parse(Data(exampleConfig.utf8))

    #expect(try Config.parse(config.encoded()) == config)
}

@Test func pausedIsFalseWhenAbsentAndRoundTrips() throws {
    var config = try Config.parse(configJSON())
    #expect(!config.paused)

    config.paused = true

    #expect(try Config.parse(config.encoded()).paused)
}

@Test func theDefaultConfigTogglesWithFnAndIsValid() throws {
    let fnToggle = Trigger(device: .builtIn, gesture: .tap(.fn, count: 2, within: .milliseconds(400)))

    #expect(Config.default.on == [fnToggle])
    #expect(Config.default.off.contains(fnToggle))
    #expect(try Config.parse(Config.default.encoded()) == Config.default)
}

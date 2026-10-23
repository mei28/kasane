import Foundation
import KasaneCore
import Testing

private let exampleConfig = """
    {
      "externalKeyboards": [
        { "name": "HHKB", "vendorID": 1278, "productID": 33 }
      ],
      "on": [
        { "device": "builtIn", "gesture": "doubleTap", "key": "fn", "withinMs": 400 }
      ],
      "off": [
        { "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 },
        { "device": "external", "gesture": "doubleTap", "key": "rightCommand", "withinMs": 400 }
      ]
    }
    """

/// A valid config with one part replaced, to test each validation rule on its own.
private func configJSON(
    externalKeyboards: String = #"[{ "name": "HHKB", "vendorID": 1278, "productID": 33 }]"#,
    on: String = #"[{ "device": "builtIn", "gesture": "doubleTap", "key": "fn", "withinMs": 400 }]"#,
    off: String = #"[{ "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 }]"#
) -> Data {
    Data(#"{ "externalKeyboards": \#(externalKeyboards), "on": \#(on), "off": \#(off) }"#.utf8)
}

@Test func acceptsTheExampleConfig() throws {
    let config = try Config.parse(Data(exampleConfig.utf8))

    #expect(
        config
            == Config(
                externalKeyboards: [ExternalKeyboard(name: "HHKB", vendorID: 1278, productID: 33)],
                on: [Trigger(device: .builtIn, gesture: .doubleTap(.fn, within: .milliseconds(400)))],
                off: [
                    Trigger(device: .external, gesture: .hold([.leftShift, .rightShift], for: .milliseconds(1000))),
                    Trigger(device: .external, gesture: .doubleTap(.rightCommand, within: .milliseconds(400))),
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

@Test func rejectsAnOffTriggerOnTheBuiltInKeyboard() {
    let off = #"""
        [
          { "device": "external", "gesture": "hold", "keys": ["leftShift", "rightShift"], "forMs": 1000 },
          { "device": "builtIn", "gesture": "doubleTap", "key": "fn", "withinMs": 400 }
        ]
        """#
    #expect(throws: ConfigError.builtInOffTrigger) {
        try Config.parse(configJSON(off: off))
    }
}

@Test func rejectsEmptyExternalKeyboards() {
    #expect(throws: ConfigError.noExternalKeyboards) {
        try Config.parse(configJSON(externalKeyboards: "[]"))
    }
}

@Test func rejectsAnUnknownKeyName() {
    #expect(throws: ConfigError.unknownKey("capsLok")) {
        try Config.parse(configJSON(on: #"[{ "device": "builtIn", "gesture": "doubleTap", "key": "capsLok", "withinMs": 400 }]"#))
    }
}

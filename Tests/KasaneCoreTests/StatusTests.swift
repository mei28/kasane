import Foundation
import KasaneCore
import Testing

// kasaned sends these to the menu bar app as JSON over XPC.

@Test func statusRoundTripsThroughJSON() throws {
    let status = Status(
        isOn: true, isPaused: false,
        safety: Safety(externalKeyboardConnected: true, screenLocked: false, onConsole: true, asleep: false),
        builtInKeyboard: .notPermitted, configError: "bad config", isRecording: false)

    #expect(try JSONDecoder().decode(Status.self, from: JSONEncoder().encode(status)) == status)
}

@Test func recordingOutcomeRoundTripsThroughJSON() throws {
    let outcomes: [RecordingOutcome] = [
        .recorded(Trigger(device: .builtIn, gesture: .tap(.fn, count: 3, within: .milliseconds(450)))),
        .rejected(.unsupportedKey(HIDUsage(page: 0x07, usage: 0x04))),
        .cancelled,
        .busy,
    ]

    #expect(try JSONDecoder().decode([RecordingOutcome].self, from: JSONEncoder().encode(outcomes)) == outcomes)
}

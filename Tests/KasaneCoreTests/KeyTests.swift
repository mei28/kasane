import KasaneCore
import Testing

// Values observed with spike/spike.swift on the built-in keyboard, except rightShift (standard HID).
@Test func keysMapToTheHIDUsagesSeenOnHardware() {
    #expect(Key.fn.usage == HIDUsage(page: 0xFF, usage: 0x03))
    #expect(Key.leftShift.usage == HIDUsage(page: 0x07, usage: 0xE1))
    #expect(Key.rightShift.usage == HIDUsage(page: 0x07, usage: 0xE5))
    #expect(Key.rightCommand.usage == HIDUsage(page: 0x07, usage: 0xE7))
}

// Standard HID keyboard page usages.
@Test func modifiersMapToTheirHIDUsages() {
    #expect(Key.leftControl.usage == HIDUsage(page: 0x07, usage: 0xE0))
    #expect(Key.leftOption.usage == HIDUsage(page: 0x07, usage: 0xE2))
    #expect(Key.leftCommand.usage == HIDUsage(page: 0x07, usage: 0xE3))
    #expect(Key.rightControl.usage == HIDUsage(page: 0x07, usage: 0xE4))
    #expect(Key.rightOption.usage == HIDUsage(page: 0x07, usage: 0xE6))
}

@Test func usagesMapBackToKeys() {
    #expect(Key(usage: HIDUsage(page: 0xFF, usage: 0x03)) == .fn)
    #expect(Key(usage: HIDUsage(page: 0x07, usage: 0xE5)) == .rightShift)
    #expect(Key(usage: HIDUsage(page: 0x07, usage: 0x04)) == nil)
}

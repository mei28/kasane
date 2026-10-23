import KasaneCore
import Testing

// Values observed with spike/spike.swift on the built-in keyboard, except rightShift (standard HID).
@Test func keysMapToTheHIDUsagesSeenOnHardware() {
    #expect(Key.fn.usage == HIDUsage(page: 0xFF, usage: 0x03))
    #expect(Key.leftShift.usage == HIDUsage(page: 0x07, usage: 0xE1))
    #expect(Key.rightShift.usage == HIDUsage(page: 0x07, usage: 0xE5))
    #expect(Key.rightCommand.usage == HIDUsage(page: 0x07, usage: 0xE7))
}

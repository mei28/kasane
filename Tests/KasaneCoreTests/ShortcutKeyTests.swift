import KasaneCore
import Testing

@Test(arguments: [
    (ShortcutKey.a, UInt32(0x04)), (.z, 0x1D), (.digit1, 0x1E), (.digit9, 0x26), (.digit0, 0x27),
    (.return, 0x28), (.escape, 0x29), (.delete, 0x2A), (.tab, 0x2B), (.space, 0x2C),
    (.right, 0x4F), (.left, 0x50), (.down, 0x51), (.up, 0x52),
])
func shortcutKeysUseTheKeyboardPageUsages(_ key: ShortcutKey, _ usage: UInt32) {
    #expect(key.usage == HIDUsage(page: 0x07, usage: usage))
}

@Test func everyShortcutKeyIsFoundByItsUsage() {
    for key in ShortcutKey.allCases {
        #expect(ShortcutKey(usage: key.usage) == key)
    }
}

@Test func modifiersAreNotShortcutKeys() {
    #expect(ShortcutKey(usage: Key.leftCommand.usage) == nil)
}

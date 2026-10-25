import KasaneCore
import Testing

// UserKeyMapping writes a usage as its page in the upper 32 bits and the usage in the lower.
private let capsLock: UInt64 = 0x7_0000_0039
private let leftControl: UInt64 = 0x7_0000_00E0
private let leftOption: UInt64 = 0x7_0000_00E2
private let leftCommand: UInt64 = 0x7_0000_00E3

@Test func substitutesTheMappedKey() {
    let remapping = KeyRemapping([(source: capsLock, destination: leftControl)])

    #expect(remapping.apply(HIDUsage(page: 0x07, usage: 0x39)) == Key.leftControl.usage)
}

@Test func leavesOtherKeysAlone() {
    let remapping = KeyRemapping([(source: capsLock, destination: leftControl)])

    #expect(remapping.apply(ShortcutKey.k.usage) == ShortcutKey.k.usage)
}

@Test func swapsKeysWithoutChaining() {
    let remapping = KeyRemapping([
        (source: leftCommand, destination: leftOption), (source: leftOption, destination: leftCommand),
    ])

    #expect(remapping.apply(Key.leftCommand.usage) == Key.leftOption.usage)
    #expect(remapping.apply(Key.leftOption.usage) == Key.leftCommand.usage)
}

@Test func readsTheVendorPageOfFn() {
    let remapping = KeyRemapping([(source: 0xFF_0000_0003, destination: leftControl)])

    #expect(remapping.apply(Key.fn.usage) == Key.leftControl.usage)
}

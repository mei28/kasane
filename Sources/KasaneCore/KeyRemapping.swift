/// The key substitutions macOS makes for one keyboard, such as Caps Lock to Control, as System
/// Settings and hidutil set them in its `UserKeyMapping`. kasaned reads keys before macOS
/// substitutes them, so it makes the same substitutions to see the keys the user typed.
public struct KeyRemapping: Equatable, Sendable {
    private var substitutes: [HIDUsage: HIDUsage] = [:]

    /// Each usage is its page in the upper 32 bits and its usage in the lower, as `UserKeyMapping`
    /// writes it.
    public init(_ pairs: [(source: UInt64, destination: UInt64)]) {
        for pair in pairs {
            substitutes[Self.usage(pair.source)] = Self.usage(pair.destination)
        }
    }

    /// The key macOS reports for `usage`. Each substitution applies once, so swapped keys stay
    /// swapped.
    public func apply(_ usage: HIDUsage) -> HIDUsage {
        substitutes[usage] ?? usage
    }

    private static func usage(_ value: UInt64) -> HIDUsage {
        HIDUsage(page: UInt32(value >> 32), usage: UInt32(value & 0xFFFF_FFFF))
    }
}

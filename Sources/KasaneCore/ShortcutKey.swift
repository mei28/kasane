/// A key that can end a keyboard shortcut, such as K in ⌃⌥⌘K: letters, digits, and the keys
/// whose labels are the same on every layout. Punctuation is left out because its label depends on
/// the layout (JIS or ANSI), and the F-keys because some keyboards send them on another page.
public enum ShortcutKey: String, CaseIterable, Sendable {
    case a
    case b
    case c
    case d
    case e
    case f
    case g
    case h
    case i
    case j
    case k
    case l
    case m
    case n
    case o
    case p
    case q
    case r
    case s
    case t
    case u
    case v
    case w
    case x
    case y
    case z
    case digit1 = "1"
    case digit2 = "2"
    case digit3 = "3"
    case digit4 = "4"
    case digit5 = "5"
    case digit6 = "6"
    case digit7 = "7"
    case digit8 = "8"
    case digit9 = "9"
    case digit0 = "0"
    case `return`
    case escape
    case delete
    case tab
    case space
    case right
    case left
    case down
    case up
}

extension ShortcutKey {
    public var usage: HIDUsage {
        let usage: UInt32 =
            switch self {
            case .a: 0x04
            case .b: 0x05
            case .c: 0x06
            case .d: 0x07
            case .e: 0x08
            case .f: 0x09
            case .g: 0x0A
            case .h: 0x0B
            case .i: 0x0C
            case .j: 0x0D
            case .k: 0x0E
            case .l: 0x0F
            case .m: 0x10
            case .n: 0x11
            case .o: 0x12
            case .p: 0x13
            case .q: 0x14
            case .r: 0x15
            case .s: 0x16
            case .t: 0x17
            case .u: 0x18
            case .v: 0x19
            case .w: 0x1A
            case .x: 0x1B
            case .y: 0x1C
            case .z: 0x1D
            case .digit1: 0x1E
            case .digit2: 0x1F
            case .digit3: 0x20
            case .digit4: 0x21
            case .digit5: 0x22
            case .digit6: 0x23
            case .digit7: 0x24
            case .digit8: 0x25
            case .digit9: 0x26
            case .digit0: 0x27
            case .return: 0x28
            case .escape: 0x29
            case .delete: 0x2A
            case .tab: 0x2B
            case .space: 0x2C
            case .right: 0x4F
            case .left: 0x50
            case .down: 0x51
            case .up: 0x52
            }
        return HIDUsage(page: 0x07, usage: usage)
    }

    /// The shortcut key a HID usage stands for, or nil for modifiers and keys kasane has no name for.
    public init?(usage: HIDUsage) {
        guard let key = ShortcutKey.allCases.first(where: { $0.usage == usage }) else { return nil }
        self = key
    }
}

extension ShortcutKey: Codable {
    public init(from decoder: any Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        guard let key = ShortcutKey(rawValue: name) else {
            throw ConfigError.unknownKey(name)
        }
        self = key
    }
}

/// A HID usage as IOKit reports it for one input element.
public struct HIDUsage: Hashable, Sendable {
    public var page: UInt32
    public var usage: UInt32

    public init(page: UInt32, usage: UInt32) {
        self.page = page
        self.usage = usage
    }
}

/// One key press or release from the built-in or an external keyboard.
public struct KeyEvent: Equatable, Sendable {
    public var device: Device
    public var usage: HIDUsage
    public var isDown: Bool
    /// Time since a fixed origin such as boot. Only differences between events matter.
    public var time: Duration

    public init(device: Device, usage: HIDUsage, isDown: Bool, time: Duration) {
        self.device = device
        self.usage = usage
        self.isDown = isDown
        self.time = time
    }
}

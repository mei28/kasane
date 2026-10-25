import IOKit.hid

/// The built-in keyboard, opened without seizing while OFF so its keys can be observed, and
/// seized while ON. The seizing process still receives the keys, so triggers keep working.
@MainActor
final class BuiltInKeyboard {
    let device: IOHIDDevice
    private let capsLockLED: IOHIDElement

    init(device: IOHIDDevice) throws(IOKitError) {
        self.device = device
        // Open before the lookup: without Input Monitoring the open fails with kIOReturnNotPermitted,
        // which kasaned waits out, while the lookup only comes back empty.
        try check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)), "open the built-in keyboard")
        let matching: [String: Any] = [
            kIOHIDElementUsagePageKey: kHIDPage_LEDs,
            kIOHIDElementUsageKey: kHIDUsage_LED_CapsLock,
        ]
        let elements = IOHIDDeviceCopyMatchingElements(device, matching as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let led = (elements as? [IOHIDElement])?.first else {
            throw IOKitError(operation: "find the caps lock LED", code: kIOReturnNotFound)
        }
        capsLockLED = led
    }

    /// Seizes the keyboard. When seizing fails, the keyboard is observed again before the
    /// seize error is thrown.
    func seize() throws(IOKitError) {
        try close()
        do {
            try check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)), "seize the built-in keyboard")
        } catch {
            try check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)), "reopen the built-in keyboard")
            throw error
        }
    }

    func release() throws(IOKitError) {
        try close()
        try check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)), "reopen the built-in keyboard")
    }

    func setCapsLockLED(_ on: Bool) throws(IOKitError) {
        let value = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, capsLockLED, 0, on ? 1 : 0)
        try check(IOHIDDeviceSetValue(device, capsLockLED, value), "turn the caps lock LED \(on ? "on" : "off")")
    }

    private func close() throws(IOKitError) {
        try check(IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)), "close the built-in keyboard")
    }
}

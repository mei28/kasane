import IOKit.hid
import KasaneCore

@MainActor
protocol KeyboardMonitorDelegate: AnyObject {
    func builtInKeyboardAppeared(_ device: IOHIDDevice)
    func builtInKeyboardDisappeared()
    func externalKeyboardCountChanged(_ count: Int)
    func keyEvent(_ event: KeyEvent)
}

/// Finds the built-in keyboard and the external keyboards, and turns their key input into
/// KeyEvents. Every keyboard that is not built in counts as external as soon as it connects.
@MainActor
final class KeyboardMonitor {
    private unowned let delegate: any KeyboardMonitorDelegate
    private let manager: IOHIDManager
    private var builtIn: IOHIDDevice?
    private var externals: [IOHIDDevice] = []

    init(delegate: any KeyboardMonitorDelegate) {
        self.delegate = delegate
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, _, _, device in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context!).takeUnretainedValue()
                MainActor.assumeIsolated { monitor.matched(device) }
            }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, _, _, device in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context!).takeUnretainedValue()
                MainActor.assumeIsolated { monitor.removed(device) }
            }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    private func matched(_ device: IOHIDDevice) {
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
        let label = "\(name.map { "\"\($0)\"" } ?? "unnamed") vendorID=\(vendorID.map(String.init) ?? "none") productID=\(productID.map(String.init) ?? "none")"

        if IOHIDDeviceGetProperty(device, kIOHIDBuiltInKey as CFString) as? Bool == true {
            guard builtIn == nil else {
                fatalError("a second built-in keyboard appeared: \(label)")
            }
            builtIn = device
            log("built-in keyboard: \(label)")
            observeInput(of: device)
            delegate.builtInKeyboardAppeared(device)
        } else {
            let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            guard result == kIOReturnSuccess else {
                log("\(IOKitError(operation: "open external keyboard \(label)", code: result)); not counting it")
                return
            }
            externals.append(device)
            log("external keyboard connected: \(label)")
            observeInput(of: device)
            delegate.externalKeyboardCountChanged(externals.count)
        }
    }

    private func removed(_ device: IOHIDDevice) {
        if device == builtIn {
            builtIn = nil
            delegate.builtInKeyboardDisappeared()
        } else if let index = externals.firstIndex(of: device) {
            externals.remove(at: index)
            log("external keyboard disconnected")
            delegate.externalKeyboardCountChanged(externals.count)
        }
    }

    private func observeInput(of device: IOHIDDevice) {
        IOHIDDeviceRegisterInputValueCallback(
            device,
            { context, _, _, value in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context!).takeUnretainedValue()
                MainActor.assumeIsolated { monitor.received(value) }
            }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }

    private func received(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        // Array slots report usage 0xFFFFFFFF. Keys live on the keyboard page and, for fn, on
        // Apple's vendor pages.
        guard usage != 0xFFFF_FFFF, page == kHIDPage_KeyboardOrKeypad || page >= 0xFF else { return }
        let device: Device = IOHIDElementGetDevice(element) == builtIn ? .builtIn : .external
        delegate.keyEvent(
            KeyEvent(
                device: device, usage: HIDUsage(page: page, usage: usage),
                isDown: IOHIDValueGetIntegerValue(value) != 0, time: uptime()))
    }
}

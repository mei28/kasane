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
    /// External keyboards that could not be opened, usually because Input Monitoring is missing.
    private var unopenedExternals: [IOHIDDevice] = []
    private let remappingReader = KeyRemappingReader()
    /// The keyboards macOS substitutes keys for, such as Caps Lock to Control.
    private var remappings: [IOHIDDevice: KeyRemapping] = [:]

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
            openExternal(device, label: label)
        }
        refreshRemappings()
    }

    /// Reads again which keys macOS substitutes on each keyboard. The substitutions are set at
    /// login, after kasaned starts, and whenever the user changes them, so kasaned reads them
    /// again from time to time.
    func refreshRemappings() {
        let current = remappingReader.remappings(for: [builtIn].compactMap { $0 } + externals)
        guard current != remappings else { return }
        remappings = current
        log("macOS substitutes keys on \(current.count) of \(externals.count + (builtIn == nil ? 0 : 1)) keyboards")
    }

    /// Tries again to open the external keyboards that could not be opened, for when Input
    /// Monitoring has been granted since.
    func retryUnopenedExternals() {
        let pending = unopenedExternals
        unopenedExternals = []
        for device in pending {
            openExternal(device, label: "retried")
        }
    }

    private func openExternal(_ device: IOHIDDevice, label: String) {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            log("\(IOKitError(operation: "open external keyboard \(label)", code: result)); not counting it yet")
            unopenedExternals.append(device)
            return
        }
        externals.append(device)
        log("external keyboard connected: \(label)")
        observeInput(of: device)
        delegate.externalKeyboardCountChanged(externals.count)
    }

    private func removed(_ device: IOHIDDevice) {
        remappings[device] = nil
        if device == builtIn {
            builtIn = nil
            delegate.builtInKeyboardDisappeared()
        } else if let index = externals.firstIndex(of: device) {
            externals.remove(at: index)
            log("external keyboard disconnected")
            delegate.externalKeyboardCountChanged(externals.count)
        } else if let index = unopenedExternals.firstIndex(of: device) {
            unopenedExternals.remove(at: index)
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
        let hidDevice = IOHIDElementGetDevice(element)
        let device: Device = hidDevice == builtIn ? .builtIn : .external
        let pressed = HIDUsage(page: page, usage: usage)
        // The key the user typed, after the substitutions macOS makes for this keyboard.
        let typed = remappings[hidDevice]?.apply(pressed) ?? pressed
        delegate.keyEvent(
            KeyEvent(
                device: device, usage: typed,
                isDown: IOHIDValueGetIntegerValue(value) != 0, time: uptime()))
    }
}

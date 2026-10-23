// Throwaway hardware checks for the built-in keyboard blocker idea.
//
//   swiftc -O spike.swift -o spike
//   ./spike led             caps LED on for 3 s, then off (non-exclusive open)
//   ./spike watch 10        print key events from the built-in keyboard for 10 s (non-exclusive)
//   sudo ./spike seize 10   seize the built-in keyboard for 10 s with the caps LED on, then exit
//   sudo ./spike seize-until-lock 20
//                           seize like seize, but release with IOHIDDeviceClose as soon as the
//                           screen locks and keep running until the 20 s are up
//
// seize exits on its own timer: with no external keyboard, Ctrl-C cannot reach the terminal.
import Foundation
import IOKit.hid

let maxSeconds = 30.0

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func check(_ ret: IOReturn, _ what: String) {
    if ret != kIOReturnSuccess {
        fail("\(what) failed: 0x\(String(UInt32(bitPattern: ret), radix: 16))")
    }
}

func builtInKeyboard() -> IOHIDDevice {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [String: Any] = [
        kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
        kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard,
        kIOHIDBuiltInKey: true,
    ]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        fail("no built-in keyboard matched")
    }
    guard devices.count == 1, let device = devices.first else {
        fail("expected exactly one built-in keyboard, got \(devices.count)")
    }
    return device
}

func capsLockElement(_ device: IOHIDDevice) -> IOHIDElement {
    let matching: [String: Any] = [
        kIOHIDElementUsagePageKey: kHIDPage_LEDs,
        kIOHIDElementUsageKey: kHIDUsage_LED_CapsLock,
    ]
    guard let elements = IOHIDDeviceCopyMatchingElements(device, matching as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement],
          let element = elements.first else {
        fail("built-in keyboard has no caps lock LED element")
    }
    return element
}

func setCapsLED(_ device: IOHIDDevice, on: Bool) {
    let element = capsLockElement(device)
    let value = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, element, 0, on ? 1 : 0)
    check(IOHIDDeviceSetValue(device, element, value), "set caps LED \(on ? "on" : "off")")
    print("caps LED \(on ? "on" : "off")")
}

func printKeyEvents(_ device: IOHIDDevice) {
    IOHIDDeviceRegisterInputValueCallback(device, { _, _, _, value in
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        // Skip array-slot noise (0xFFFFFFFF, and the 0x01 ErrorRollOver release the built-in
        // keyboard reports after almost every key); keep keyboard page (0x07) and Apple vendor
        // pages (fn is 0xFF/0x03).
        guard usage != 0xFFFF_FFFF, (page == 0x07 && usage >= 0x04) || page >= 0xFF else { return }
        let state = IOHIDValueGetIntegerValue(value) != 0 ? "down" : "up"
        print(String(format: "page 0x%02X usage 0x%02X %@", page, usage, state))
    }, nil)
    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
}

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: Date())
}

// The signal the daemon would use: IOConsoleUsers on the registry root, readable without a GUI session.
func screenIsLocked(_ registryRoot: io_registry_entry_t) -> Bool {
    guard let users = IORegistryEntryCreateCFProperty(registryRoot, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
        .takeRetainedValue() as? [[String: Any]] else {
        fail("IOConsoleUsers missing from the registry root")
    }
    guard let console = users.first(where: { $0["kCGSSessionOnConsoleKey"] as? Bool == true }) else {
        fail("no session is on console")
    }
    return console["CGSSessionScreenIsLocked"] as? Bool == true
}

func seconds(_ args: [String]) -> Double {
    guard args.count >= 3, let s = Double(args[2]), s > 0, s <= maxSeconds else {
        fail("give a duration in seconds, 0 < s <= \(Int(maxSeconds))")
    }
    return s
}

let args = CommandLine.arguments
guard args.count >= 2 else { fail("usage: spike led | watch <s> | seize <s> | seize-until-lock <s>") }
let device = builtInKeyboard()

switch args[1] {
case "led":
    check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)), "open")
    setCapsLED(device, on: true)
    Thread.sleep(forTimeInterval: 3)
    setCapsLED(device, on: false)
case "watch":
    let duration = seconds(args)
    check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)), "open")
    printKeyEvents(device)
    print("watching built-in keyboard for \(Int(duration)) s (keys still reach the system)")
    CFRunLoopRunInMode(.defaultMode, duration, false)
case "seize":
    let duration = seconds(args)
    check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)), "seize")
    setCapsLED(device, on: true)
    printKeyEvents(device)
    print("seized built-in keyboard for \(Int(duration)) s; try the keys, trackpad and Touch ID button")
    CFRunLoopRunInMode(.defaultMode, duration, false)
    setCapsLED(device, on: false)
    print("releasing on exit")
case "seize-until-lock":
    let duration = seconds(args)
    let registryRoot = IORegistryGetRootEntry(kIOMainPortDefault)
    check(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)), "seize")
    setCapsLED(device, on: true)
    printKeyEvents(device)
    print("\(timestamp()) seized built-in keyboard for up to \(Int(duration)) s; try the trackpad, then lock with the Touch ID button")
    var seized = true
    let poll = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + 0.2, 0.2, 0, 0) { timer in
        guard screenIsLocked(registryRoot) else { return }
        setCapsLED(device, on: false)
        check(IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)), "close")
        seized = false
        print("\(timestamp()) screen locked; released with IOHIDDeviceClose, process keeps running")
        CFRunLoopTimerInvalidate(timer)
    }
    CFRunLoopAddTimer(CFRunLoopGetMain(), poll, .defaultMode)
    CFRunLoopRunInMode(.defaultMode, duration, false)
    if seized {
        setCapsLED(device, on: false)
        print("\(timestamp()) no lock seen; releasing on exit")
    } else {
        print("\(timestamp()) exiting")
    }
default:
    fail("unknown mode \(args[1])")
}

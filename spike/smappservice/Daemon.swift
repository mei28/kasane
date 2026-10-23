// Spike daemon: started by launchd through SMAppService. Logs whether it can open the built-in
// keyboard, and serves ping / seize over XPC to clients signed by the same certificate.
import Foundation
import IOKit.hid

func log(_ message: String) {
    FileHandle.standardError.write(Data("\(Date()) \(message)\n".utf8))
}

func hex(_ code: IOReturn) -> String { "0x" + String(UInt32(bitPattern: code), radix: 16) }

func builtInKeyboard() -> IOHIDDevice? {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [String: Any] = [
        kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
        kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard,
        kIOHIDBuiltInKey: true,
    ]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    return (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first
}

final class Service: NSObject, SpikeProtocol, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        log("accepting connection from pid \(connection.processIdentifier)")
        connection.exportedInterface = NSXPCInterface(with: SpikeProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func ping(reply: @escaping (String) -> Void) {
        guard let device = builtInKeyboard() else { return reply("uid=\(getuid()) no built-in keyboard") }
        let open = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        if open == kIOReturnSuccess { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        reply("uid=\(getuid()) open built-in: \(hex(open))")
    }

    func seize(seconds: Double, reply: @escaping (String) -> Void) {
        guard let device = builtInKeyboard() else { return reply("no built-in keyboard") }
        let seize = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard seize == kIOReturnSuccess else { return reply("seize: \(hex(seize))") }
        log("seized for \(seconds) s")
        Thread.sleep(forTimeInterval: seconds)
        let close = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        log("released: \(hex(close))")
        reply("seized for \(seconds) s, close: \(hex(close))")
    }
}

// Bumped on each rebuild so the log shows which binary launchd started.
let build = 4
log("started: build=\(build) uid=\(getuid()) pid=\(getpid()) path=\(CommandLine.arguments[0])")
if let device = builtInKeyboard() {
    log("open built-in at start: \(hex(IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))))")
} else {
    log("no built-in keyboard at start")
}
let requirement = sameCertificateRequirement(identifier: "dev.mei.kasane.spike")
log("client requirement: \(requirement)")
let service = Service()
let listener = NSXPCListener(machServiceName: machServiceName)
listener.setConnectionCodeSigningRequirement(requirement)
listener.delegate = service
listener.resume()
dispatchMain()

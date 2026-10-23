import IOKit
import IOKit.pwr_mgt

// iokit_common_msg() values from IOMessage.h. Swift does not import the function-like macro.
private let kIOMessageCanSystemSleep: UInt32 = 0xE000_0270
private let kIOMessageSystemWillSleep: UInt32 = 0xE000_0280
private let kIOMessageSystemHasPoweredOn: UInt32 = 0xE000_0300

@MainActor
protocol PowerMonitorDelegate: AnyObject {
    func systemWillSleep()
    func systemDidWake()
}

/// Reports system sleep and wake. Sleep waits until the delegate returns, so the built-in
/// keyboard is released before the system sleeps.
@MainActor
final class PowerMonitor {
    private unowned let delegate: any PowerMonitorDelegate
    private var rootPort: io_connect_t = 0
    private var notifier: io_object_t = 0

    init(delegate: any PowerMonitorDelegate) throws(IOKitError) {
        self.delegate = delegate
        var port: IONotificationPortRef?
        rootPort = IORegisterForSystemPower(
            Unmanaged.passUnretained(self).toOpaque(), &port,
            { refcon, _, messageType, messageArgument in
                let monitor = Unmanaged<PowerMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                MainActor.assumeIsolated {
                    monitor.handle(messageType, Int(bitPattern: messageArgument))
                }
            }, &notifier)
        guard rootPort != 0, let port else {
            throw IOKitError(operation: "register for system power notifications", code: kIOReturnError)
        }
        CFRunLoopAddSource(
            CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
    }

    private func handle(_ messageType: UInt32, _ argument: Int) {
        switch messageType {
        case kIOMessageCanSystemSleep:
            IOAllowPowerChange(rootPort, argument)
        case kIOMessageSystemWillSleep:
            delegate.systemWillSleep()
            IOAllowPowerChange(rootPort, argument)
        case kIOMessageSystemHasPoweredOn:
            delegate.systemDidWake()
        default:
            break
        }
    }
}

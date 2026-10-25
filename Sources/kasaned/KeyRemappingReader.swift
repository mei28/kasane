import Foundation
import IOKit.hid
import KasaneCore

/// Reads the key substitutions macOS makes for each keyboard from the HID event system, where
/// System Settings and hidutil keep them as each keyboard service's `UserKeyMapping`.
@MainActor
struct KeyRemappingReader {
    private let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)

    /// The substitutions for each of `devices` that has any.
    func remappings(for devices: [IOHIDDevice]) -> [IOHIDDevice: KeyRemapping] {
        let byDeviceEntry = remappingsByDeviceEntry()
        var remappings: [IOHIDDevice: KeyRemapping] = [:]
        for device in devices {
            var entryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entryID)
            remappings[device] = byDeviceEntry[entryID]
        }
        return remappings
    }

    /// The substitutions of every keyboard service that has any, by the registry entry ID of the
    /// IOHIDDevice the service belongs to.
    private func remappingsByDeviceEntry() -> [UInt64: KeyRemapping] {
        // A nil array means the event system has no services at all.
        let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] ?? []
        var remappings: [UInt64: KeyRemapping] = [:]
        for service in services
        where IOHIDServiceClientConformsTo(service, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard)) != 0 {
            guard let remapping = remapping(of: service), let device = deviceEntryID(of: service) else { continue }
            remappings[device] = remapping
        }
        return remappings
    }

    private func remapping(of service: IOHIDServiceClient) -> KeyRemapping? {
        guard let property = IOHIDServiceClientCopyProperty(service, kIOHIDUserKeyUsageMapKey as CFString) else {
            return nil
        }
        guard let entries = property as? [[String: Any]] else {
            log("ignoring an unreadable \(kIOHIDUserKeyUsageMapKey): \(property)")
            return nil
        }
        var pairs: [(source: UInt64, destination: UInt64)] = []
        for entry in entries {
            guard let source = entry[kIOHIDKeyboardModifierMappingSrcKey] as? NSNumber,
                let destination = entry[kIOHIDKeyboardModifierMappingDstKey] as? NSNumber
            else {
                log("ignoring an unreadable \(kIOHIDUserKeyUsageMapKey): \(property)")
                return nil
            }
            pairs.append((source.uint64Value, destination.uint64Value))
        }
        return pairs.isEmpty ? nil : KeyRemapping(pairs)
    }

    /// The registry entry ID of the IOHIDDevice above a keyboard service, a few levels up the
    /// service plane (event service, then interface, then device).
    private func deviceEntryID(of service: IOHIDServiceClient) -> UInt64? {
        guard let serviceID = IOHIDServiceClientGetRegistryID(service) as? NSNumber else { return nil }
        var entry = IOServiceGetMatchingService(kIOMainPortDefault, IORegistryEntryIDMatching(serviceID.uint64Value))
        while entry != IO_OBJECT_NULL {
            if IOObjectConformsTo(entry, kIOHIDDeviceKey) != 0 {
                var entryID: UInt64 = 0
                IORegistryEntryGetRegistryEntryID(entry, &entryID)
                IOObjectRelease(entry)
                return entryID
            }
            var parent: io_registry_entry_t = IO_OBJECT_NULL
            let result = IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)
            IOObjectRelease(entry)
            guard result == KERN_SUCCESS else { return nil }
            entry = parent
        }
        return nil
    }
}

import IOKit

struct IOKitError: Error, CustomStringConvertible {
    let operation: String
    let code: IOReturn

    var description: String {
        "\(operation) failed: 0x\(String(UInt32(bitPattern: code), radix: 16))"
    }
}

func check(_ code: IOReturn, _ operation: String) throws(IOKitError) {
    guard code == kIOReturnSuccess else {
        throw IOKitError(operation: operation, code: code)
    }
}

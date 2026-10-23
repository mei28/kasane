// Spike app: registers the bundled daemon with SMAppService and talks to it over XPC.
//   KasaneSpike register | status | unregister | settings | ping | seize <s>
import Foundation
import ServiceManagement

let service = SMAppService.daemon(plistName: "dev.mei.kasaned.spike.plist")

func describe(_ status: SMAppService.Status) -> String {
    switch status {
    case .notRegistered: "notRegistered"
    case .enabled: "enabled"
    case .requiresApproval: "requiresApproval"
    case .notFound: "notFound"
    @unknown default: "unknown(\(status.rawValue))"
    }
}

func call(_ body: @escaping (SpikeProtocol, @escaping (String) -> Void) -> Void) {
    let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
    connection.remoteObjectInterface = NSXPCInterface(with: SpikeProtocol.self)
    connection.setCodeSigningRequirement(sameCertificateRequirement(identifier: "dev.mei.kasane.spike"))
    connection.invalidationHandler = { print("connection invalidated"); exit(2) }
    connection.resume()
    let proxy = connection.remoteObjectProxyWithErrorHandler { error in
        print("XPC error: \(error)")
        exit(2)
    }
    guard let spike = proxy as? SpikeProtocol else { fail("proxy does not conform") }
    body(spike) { answer in
        print(answer)
        exit(0)
    }
    dispatchMain()
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else { fail("usage: KasaneSpike register|status|unregister|settings|ping|seize <s>") }
switch arguments[1] {
case "register":
    do { try service.register() } catch { print("register failed: \(error)") }
    print("status: \(describe(service.status))")
case "status":
    print("status: \(describe(service.status))")
case "unregister":
    do { try service.unregister() } catch { print("unregister failed: \(error)") }
    print("status: \(describe(service.status))")
case "settings":
    SMAppService.openSystemSettingsLoginItems()
case "ping":
    call { spike, done in spike.ping(reply: done) }
case "seize":
    guard arguments.count == 3, let seconds = Double(arguments[2]), seconds > 0, seconds <= 10 else {
        fail("seize <seconds, at most 10>")
    }
    call { spike, done in spike.seize(seconds: seconds, reply: done) }
default:
    fail("unknown command \(arguments[1])")
}

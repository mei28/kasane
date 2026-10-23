import Foundation
import KasaneIPC
import Synchronization

/// Accepts XPC connections from the menu bar app. The listener only lets in code signed with
/// the same identity as kasaned; each connection gets its own service object, so kasaned can
/// tell which client started a recording.
///
/// NSXPCListener calls the delegate on its own queue, so nothing here is main-actor isolated.
final class XPCServer: NSObject, NSXPCListenerDelegate, Sendable {
    private let daemon: Daemon
    private let nextConnectionID = Atomic<Int>(0)
    private nonisolated(unsafe) let listener = NSXPCListener(machServiceName: daemonServiceName)

    init(daemon: Daemon, clientRequirement: String) {
        self.daemon = daemon
        super.init()
        listener.setConnectionCodeSigningRequirement(clientRequirement)
        listener.delegate = self
        listener.resume()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let id = nextConnectionID.add(1, ordering: .relaxed).newValue
        connection.exportedInterface = NSXPCInterface(with: KasaneDaemonProtocol.self)
        connection.exportedObject = DaemonService(daemon: daemon, connectionID: id)
        connection.invalidationHandler = { [daemon] in
            Task { @MainActor in daemon.connectionClosed(id) }
        }
        connection.resume()
        return true
    }
}

/// One client's view of kasaned. Every call hops to the main actor, where the Daemon lives.
private final class DaemonService: NSObject, KasaneDaemonProtocol, Sendable {
    private let daemon: Daemon
    private let connectionID: Int

    init(daemon: Daemon, connectionID: Int) {
        self.daemon = daemon
        self.connectionID = connectionID
    }

    func status(reply: @escaping @Sendable (Data) -> Void) {
        Task { @MainActor in reply(daemon.statusData()) }
    }

    func setBlocked(_ blocked: Bool, reply: @escaping @Sendable (Data) -> Void) {
        Task { @MainActor in reply(daemon.setBlocked(blocked)) }
    }

    func setPaused(_ paused: Bool, reply: @escaping @Sendable (Data) -> Void) {
        Task { @MainActor in reply(daemon.setPaused(paused)) }
    }

    func config(reply: @escaping @Sendable (Data) -> Void) {
        Task { @MainActor in reply(daemon.configData()) }
    }

    func applyConfig(_ config: Data, reply: @escaping @Sendable (Data) -> Void) {
        Task { @MainActor in reply(daemon.applyConfig(config)) }
    }

    func record(reply: @escaping @Sendable (Data) -> Void) {
        let id = connectionID
        Task { @MainActor in daemon.record(for: id, reply: reply) }
    }

    func cancelRecording() {
        let id = connectionID
        Task { @MainActor in daemon.cancelRecording(for: id) }
    }
}

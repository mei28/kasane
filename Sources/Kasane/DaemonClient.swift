import Foundation
import KasaneCore
import KasaneIPC
import notify

/// The app's connection to kasaned. `status` is nil while kasaned cannot be reached.
///
/// kasaned posts `statusChangedNotification` whenever its status changes, and the client asks
/// for the status again; while kasaned is unreachable the client also asks every 5 seconds, so
/// the menu notices kasaned starting.
@MainActor
final class DaemonClient: ObservableObject {
    @Published private(set) var status: Status?
    /// Why the last request failed, for the settings window.
    @Published private(set) var lastError: String?

    private let requirement: String
    private var connection: NSXPCConnection?
    private var notifyToken: Int32 = 0
    private var retryTimer: Timer?

    init() throws(SigningRequirementError) {
        requirement = try sameSignerRequirement()
        let result = notify_register_dispatch(statusChangedNotification, &notifyToken, .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        precondition(result == NOTIFY_STATUS_OK, "notify_register_dispatch failed: \(result)")
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.status == nil else { return }
                self.refresh()
            }
        }
        refresh()
    }

    func refresh() {
        Task { await update { try await self.call(Status.self) { $0.status(reply: $1) } } }
    }

    func setBlocked(_ blocked: Bool) {
        Task { await update { try await self.call(Status.self) { $0.setBlocked(blocked, reply: $1) } } }
    }

    func setPaused(_ paused: Bool) {
        Task { await update { try await self.call(Status.self) { $0.setPaused(paused, reply: $1) } } }
    }

    /// The config in use. Decoded without validation: when kasaned's own file is broken, it
    /// reports an empty config and the settings window has to be able to show it.
    func config() async throws -> Config {
        try await call(Config.self) { $0.config(reply: $1) }
    }

    func apply(_ config: Config) async throws -> ConfigApplyOutcome {
        let data = try config.encoded()
        return try await call(ConfigApplyOutcome.self) { $0.applyConfig(data, reply: $1) }
    }

    /// Records the next gesture; returns when the recording ends.
    func record() async throws -> RecordingOutcome {
        try await call(RecordingOutcome.self) { $0.record(reply: $1) }
    }

    func cancelRecording() {
        proxy { _ in }.cancelRecording()
    }

    private func update(_ fetch: () async throws -> Status) async {
        do {
            status = try await fetch()
            lastError = nil
        } catch {
            status = nil
            lastError = "\(error)"
        }
    }

    private func call<Reply: Decodable>(
        _ type: Reply.Type, _ send: (any KasaneDaemonProtocol, @escaping @Sendable (Data) -> Void) -> Void
    ) async throws -> Reply {
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            // XPC calls exactly one of the two: the reply, or the error handler.
            send(proxy { continuation.resume(throwing: $0) }) { continuation.resume(returning: $0) }
        }
        return try JSONDecoder().decode(Reply.self, from: data)
    }

    private func proxy(onError: @escaping @Sendable (any Error) -> Void) -> any KasaneDaemonProtocol {
        guard let proxy = activeConnection.remoteObjectProxyWithErrorHandler(onError) as? any KasaneDaemonProtocol
        else { preconditionFailure("the XPC proxy does not conform to KasaneDaemonProtocol") }
        return proxy
    }

    private var activeConnection: NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: daemonServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: KasaneDaemonProtocol.self)
        // Only talk to a kasaned signed with the same identity as this app.
        connection.setCodeSigningRequirement(requirement)
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.status = nil
            }
        }
        // kasaned restarted; its state starts over, so ask again.
        connection.interruptionHandler = { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        connection.resume()
        self.connection = connection
        return connection
    }
}

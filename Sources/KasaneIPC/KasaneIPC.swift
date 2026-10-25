import CryptoKit
import Foundation
import Security

/// The Mach service kasaned listens on. The LaunchDaemon plist declares it.
public let daemonServiceName = "dev.mei.kasane.daemon"

/// The notify(3) name kasaned posts whenever its status changes. The app then asks for the status
/// again, so kasaned never has to hold on to its clients.
public let statusChangedNotification = "dev.mei.kasane.changed"

/// kasaned and the app are both signed with this identifier. Input Monitoring is granted to the
/// signing identifier, so one grant to Kasane covers the daemon too.
public let signingIdentifier = "dev.mei.kasane"

/// What the menu bar app can ask kasaned. Every payload is JSON of a KasaneCore type.
@objc public protocol KasaneDaemonProtocol {
    /// Replies with a `Status`.
    func status(reply: @escaping @Sendable (Data) -> Void)
    /// Turns blocking ON or OFF as a trigger would, then replies with the `Status`.
    func setBlocked(_ blocked: Bool, reply: @escaping @Sendable (Data) -> Void)
    /// Pauses or resumes kasane, then replies with the `Status`.
    func setPaused(_ paused: Bool, reply: @escaping @Sendable (Data) -> Void)
    /// Replies with the `Config` in use, or JSON null while the config file is unusable.
    func config(reply: @escaping @Sendable (Data) -> Void)
    /// Validates, saves, and uses a `Config`, then replies with a `ConfigApplyOutcome`.
    func applyConfig(_ config: Data, reply: @escaping @Sendable (Data) -> Void)
    /// Records the next gesture and replies with a `RecordingOutcome` when it ends.
    func record(reply: @escaping @Sendable (Data) -> Void)
    func cancelRecording()
}

public enum SigningRequirementError: Error, CustomStringConvertible {
    case notSignedWithACertificate
    case invalid(String)

    public var description: String {
        switch self {
        case .notSignedWithACertificate: "this process is not signed with a certificate"
        case .invalid(let requirement): "not a valid code requirement: \(requirement)"
        }
    }
}

/// A code requirement for `signingIdentifier` signed by the same leaf certificate as this process.
/// kasaned and the app each check the other with it, so only code signed with the kasane
/// identity on this Mac can talk to kasaned.
public func sameSignerRequirement() throws(SigningRequirementError) -> String {
    var code: SecCode?
    var staticCode: SecStaticCode?
    var information: CFDictionary?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
        SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
        SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
            == errSecSuccess,
        let certificates = (information as? [String: Any])?[kSecCodeInfoCertificates as String] as? [SecCertificate],
        let leaf = certificates.first
    else { throw .notSignedWithACertificate }

    let hash = Insecure.SHA1.hash(data: SecCertificateCopyData(leaf) as Data)
    let requirement =
        "identifier \"\(signingIdentifier)\" and certificate leaf = H\"\(hash.map { String(format: "%02x", $0) }.joined())\""
    // NSXPC raises an Objective-C exception on a malformed requirement, so check it first.
    var parsed: SecRequirement?
    guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess else {
        throw .invalid(requirement)
    }
    return requirement
}

// Shared by both spike executables: the XPC interface and the code signing requirement.
import CryptoKit
import Foundation
import Security

let machServiceName = "dev.mei.kasane.spike.daemon"

@objc protocol SpikeProtocol {
    func ping(reply: @escaping (String) -> Void)
    func seize(seconds: Double, reply: @escaping (String) -> Void)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// A requirement that matches `identifier` signed by the same leaf certificate as this process.
func sameCertificateRequirement(identifier: String) -> String {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { fail("SecCodeCopySelf") }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
        fail("SecCodeCopyStaticCode")
    }
    var info: CFDictionary?
    guard
        SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
            == errSecSuccess,
        let certificates = (info as? [String: Any])?[kSecCodeInfoCertificates as String] as? [SecCertificate],
        let leaf = certificates.first
    else { fail("this process is not signed with a certificate") }
    let hash = Insecure.SHA1.hash(data: SecCertificateCopyData(leaf) as Data)
    let hex = hash.map { String(format: "%02x", $0) }.joined()
    let requirement = "identifier \"\(identifier)\" and certificate leaf = H\"\(hex)\""
    var parsed: SecRequirement?
    guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess else {
        fail("bad requirement: \(requirement)")
    }
    return requirement
}

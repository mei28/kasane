import Foundation

/// Writes one timestamped line to stderr. Run by hand, it shows in the terminal; as a
/// LaunchDaemon, StandardErrorPath collects it.
func log(_ message: String) {
    let time = Date.now.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current))
    let line = "\(time) \(message)\n"
    FileHandle.standardError.write(Data(line.utf8))
}

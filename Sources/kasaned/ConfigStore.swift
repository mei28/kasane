import Foundation
import KasaneCore

/// The config file kasaned owns. Only root can write it; the menu bar app changes it through
/// kasaned, which validates every config before saving it.
struct ConfigStore {
    let url = URL(filePath: "/Library/Application Support/Kasane/config.json")

    /// Reads the config, writing the default one first when there is no file yet.
    func load() throws -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else {
            try save(.default)
            log("wrote the default config to \(url.path)")
            return .default
        }
        return try Config.parse(Data(contentsOf: url))
    }

    func save(_ config: Config) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try config.encoded().write(to: url, options: .atomic)
    }
}

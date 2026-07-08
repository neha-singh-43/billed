import Foundation

public final class ConfigManager: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var _config: BilledConfig

    public var config: BilledConfig {
        lock.lock()
        defer { lock.unlock() }
        return _config
    }

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".config/billed")
        self.fileURL = dir.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(BilledConfig.self, from: data)
        {
            _config = BilledConfig.merging(saved: saved)
        } else {
            _config = BilledConfig.merging(saved: nil)
            try? persist(_config)
        }
    }

    public func isEnabled(_ provider: ServiceProvider) -> Bool {
        config.config(for: provider.rawValue)?.enabled ?? true
    }

    public func setEnabled(_ provider: ServiceProvider, _ enabled: Bool) {
        lock.lock()
        if let idx = _config.providers.firstIndex(where: { $0.id == provider.rawValue }) {
            _config.providers[idx].enabled = enabled
        }
        let config = _config
        lock.unlock()
        try? persist(config)
    }

    private func persist(_ config: BilledConfig) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

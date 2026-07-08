import Foundation

public struct BilledConfig: Codable, Sendable {
    public var version: Int
    public var providers: [ProviderConfig]

    public init(version: Int = 1, providers: [ProviderConfig]) {
        self.version = version
        self.providers = providers
    }

    public func config(for id: String) -> ProviderConfig? {
        providers.first { $0.id == id }
    }

    public static func merging(saved: BilledConfig?) -> BilledConfig {
        var providers = saved?.providers ?? []
        for sp in ServiceProvider.allCases {
            if !providers.contains(where: { $0.id == sp.rawValue }) {
                providers.append(ProviderConfig(id: sp.rawValue))
            }
        }
        return BilledConfig(version: saved?.version ?? 1, providers: providers)
    }
}

public struct ProviderConfig: Codable, Sendable, Equatable {
    public var id: String
    public var enabled: Bool
    public var source: String

    public init(id: String, enabled: Bool = true, source: String = "auto") {
        self.id = id
        self.enabled = enabled
        self.source = source
    }
}

import Foundation

public struct UsageCachePayload: Codable, Sendable {
    public var summary: UsageSummarySnapshot?
    public var events: [UsageEvent]
    public var lastSuccessfulFetch: Date?

    public init(summary: UsageSummarySnapshot? = nil, events: [UsageEvent] = [], lastSuccessfulFetch: Date? = nil) {
        self.summary = summary
        self.events = events
        self.lastSuccessfulFetch = lastSuccessfulFetch
    }
}

public struct LocalCache: Sendable {
    public static let retentionDays = 90

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Billed", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("usage-cache.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> UsageCachePayload {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? decoder.decode(UsageCachePayload.self, from: data)
        else { return UsageCachePayload() }
        return payload
    }

    public func save(_ payload: UsageCachePayload) throws {
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }

    public func mergeEvents(_ incoming: [UsageEvent], existing: [UsageEvent]) -> [UsageEvent] {
        var byKey: [String: UsageEvent] = [:]
        for event in existing + incoming {
            let key = "\(Int(event.timestamp.timeIntervalSince1970 * 1000))-\(event.model)-\(event.chargedCents)"
            byKey[key] = event
        }
        let cutoff = Date().addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        return byKey.values.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp > $1.timestamp }
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

import Foundation

public enum CursorAPIError: Error, LocalizedError {
    case sessionExpired
    case rateLimited
    case http(status: Int, body: String)
    case transport(Error)
    case decoding(Error)

    public var errorDescription: String? {
        switch self {
        case .sessionExpired: "Session expired — sign in to the Cursor app again."
        case .rateLimited: "Rate limited — showing cached data."
        case .http(let status, _): "Request failed (HTTP \(status))."
        case .transport(let error): error.localizedDescription
        case .decoding(let error): "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

public protocol UsageDataSource: Sendable {
    func usageSummary() async throws -> UsageSummarySnapshot
    func usageEvents(since: Date, until: Date) async throws -> [UsageEvent]
}

public struct DashboardClient: UsageDataSource, Sendable {
    private let baseURL: URL
    private let sessionCookie: String
    private let session: URLSession

    public init(sessionCookie: String, baseURL: URL = URL(string: "https://cursor.com")!, session: URLSession = .shared) {
        self.sessionCookie = sessionCookie
        self.baseURL = baseURL
        self.session = session
    }

    public func usageSummary() async throws -> UsageSummarySnapshot {
        let data = try await request(method: "GET", path: "/api/usage-summary")
        do {
            let dto = try JSONDecoder().decode(UsageSummaryDTO.self, from: data)
            return dto.toDomain()
        } catch {
            throw CursorAPIError.decoding(error)
        }
    }

    public func usageEvents(since: Date, until: Date) async throws -> [UsageEvent] {
        var all: [UsageEvent] = []
        var page = 1
        let startMs = Int(since.timeIntervalSince1970 * 1000)
        let endMs = Int(until.timeIntervalSince1970 * 1000)

        while true {
            let body: [String: Any] = [
                "startDate": String(startMs),
                "endDate": String(endMs),
                "page": page,
                "pageSize": 100,
            ]
            let data = try await request(method: "POST", path: "/api/dashboard/get-filtered-usage-events", json: body)
            let response: EventsResponseDTO
            do {
                response = try JSONDecoder().decode(EventsResponseDTO.self, from: data)
            } catch {
                throw CursorAPIError.decoding(error)
            }
            all.append(contentsOf: response.events.map { $0.toDomain() })
            let total = response.totalUsageEventsCount ?? all.count
            if response.events.isEmpty || all.count >= total || page >= 200 { break }
            page += 1
        }
        return all
    }

    private func request(method: String, path: String, json: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path) else {
            throw CursorAPIError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("WorkosCursorSessionToken=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.setValue("https://cursor.com/dashboard/usage", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Billed/0.1", forHTTPHeaderField: "User-Agent")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CursorAPIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CursorAPIError.transport(URLError(.badServerResponse))
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 { throw CursorAPIError.sessionExpired }
            if http.statusCode == 429 { throw CursorAPIError.rateLimited }
            throw CursorAPIError.http(status: http.statusCode, body: body)
        }
        return data
    }
}

// MARK: - DTOs

private struct UsageSummaryDTO: Decodable {
    let billingCycleStart: String
    let billingCycleEnd: String
    let membershipType: String?
    let limitType: String?
    let individualUsage: IndividualUsageDTO?
    let teamUsage: TeamUsageDTO?

    func toDomain() -> UsageSummarySnapshot {
        UsageSummarySnapshot(
            cycleStart: ISO8601DateParser.parse(billingCycleStart) ?? .distantPast,
            cycleEnd: ISO8601DateParser.parse(billingCycleEnd) ?? .distantFuture,
            membershipType: membershipType,
            limitType: limitType,
            teamPooledUsed: teamUsage?.pooled?.used,
            teamPooledLimit: teamUsage?.pooled?.limit,
            teamPooledRemaining: teamUsage?.pooled?.remaining,
            onDemandUsed: teamUsage?.onDemand?.used.map(Double.init),
            individualOverallUsed: individualUsage?.overall?.used
        )
    }
}

private struct IndividualUsageDTO: Decodable {
    let overall: QuotaBucketDTO?
}

private struct TeamUsageDTO: Decodable {
    let pooled: QuotaBucketDTO?
    let onDemand: OnDemandBucketDTO?
}

private struct QuotaBucketDTO: Decodable {
    let used: Int?
    let limit: Int?
    let remaining: Int?
}

private struct OnDemandBucketDTO: Decodable {
    let used: Int?
}

private struct EventsResponseDTO: Decodable {
    let totalUsageEventsCount: Int?
    let events: [EventDTO]

    enum CodingKeys: String, CodingKey {
        case totalUsageEventsCount
        case usageEventsDisplay
        case usageEvents
        case events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalUsageEventsCount = try container.decodeIfPresent(Int.self, forKey: .totalUsageEventsCount)

        // Decode the events array from whichever key is present. We intentionally
        // do NOT swallow decode errors here: if the events key exists but its
        // shape changed (schema drift on Cursor's side), we want that surfaced as
        // a `.decoding` error so the UI shows an error/stale banner — rather than
        // silently returning [] which makes a broken fetch look like a successful
        // "0 events" refresh and blanks the panel with no warning.
        if container.contains(.usageEventsDisplay) {
            events = try container.decode([EventDTO].self, forKey: .usageEventsDisplay)
        } else if container.contains(.usageEvents) {
            events = try container.decode([EventDTO].self, forKey: .usageEvents)
        } else if container.contains(.events) {
            events = try container.decode([EventDTO].self, forKey: .events)
        } else {
            // No events key at all → genuinely empty result, not an error.
            events = []
        }
    }
}

private struct EventDTO: Decodable {
    let timestamp: FlexibleMillis
    let model: String?
    let kind: String?
    let isTokenBasedCall: Bool?
    let isHeadless: Bool?
    let tokenUsage: TokenUsageDTO?
    let chargedCents: Double?
    let cursorTokenFee: Double?

    func toDomain() -> UsageEvent {
        let tokens: TokenUsage?
        if isTokenBasedCall == true, let t = tokenUsage {
            tokens = TokenUsage(
                input: t.inputTokens ?? 0,
                output: t.outputTokens ?? 0,
                cacheWrite: t.cacheWriteTokens ?? 0,
                cacheRead: t.cacheReadTokens ?? 0
            )
        } else {
            tokens = nil
        }
        return UsageEvent(
            timestamp: EpochMillisParser.parse(timestamp.value) ?? .distantPast,
            model: model ?? "unknown",
            kind: BillingKind(rawKind: kind ?? ""),
            isTokenBased: isTokenBasedCall ?? false,
            isHeadless: isHeadless ?? false,
            tokens: tokens,
            chargedCents: chargedCents ?? 0,
            cursorTokenFee: cursorTokenFee
        )
    }
}

/// Epoch-milliseconds value that tolerates the API returning it as either a
/// JSON string ("1782309582770") or a number (1782309582770). Stored normalized
/// as a string so the rest of the pipeline is unaffected by which form Cursor
/// sends. This keeps a string↔number change from breaking the events fetch.
private struct FlexibleMillis: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            value = s
        } else if let i = try? container.decode(Int64.self) {
            value = String(i)
        } else if let d = try? container.decode(Double.self) {
            value = String(Int64(d))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected epoch-millis timestamp as String or number"
            )
        }
    }
}

private struct TokenUsageDTO: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheWriteTokens: Int?
    let cacheReadTokens: Int?
    let totalCents: Double?
}

enum ISO8601DateParser {
    static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

enum EpochMillisParser {
    static func parse(_ value: String) -> Date? {
        guard let ms = Double(value) else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}

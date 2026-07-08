import Foundation

public enum BillingKind: Equatable, Sendable, Codable {
    case includedInSubscription
    case usageBased
    case other(String)

    enum CodingKeys: String, CodingKey {
        case type
        case raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "included": self = .includedInSubscription
        case "usageBased": self = .usageBased
        case "other":
            self = .other(try container.decode(String.self, forKey: .raw))
        default:
            self = .other(type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .includedInSubscription:
            try container.encode("included", forKey: .type)
        case .usageBased:
            try container.encode("usageBased", forKey: .type)
        case .other(let raw):
            try container.encode("other", forKey: .type)
            try container.encode(raw, forKey: .raw)
        }
    }

    public init(rawKind: String) {
        let lower = rawKind.lowercased()
        if lower.contains("included") {
            self = .includedInSubscription
        } else if lower.contains("usage") {
            self = .usageBased
        } else {
            self = .other(rawKind)
        }
    }
}

public struct TokenUsage: Equatable, Sendable, Codable {
    public var input: Int
    public var output: Int
    public var cacheWrite: Int
    public var cacheRead: Int

    public init(input: Int = 0, output: Int = 0, cacheWrite: Int = 0, cacheRead: Int = 0) {
        self.input = input
        self.output = output
        self.cacheWrite = cacheWrite
        self.cacheRead = cacheRead
    }

    public var total: Int { input + output + cacheWrite + cacheRead }

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            input: lhs.input + rhs.input,
            output: lhs.output + rhs.output,
            cacheWrite: lhs.cacheWrite + rhs.cacheWrite,
            cacheRead: lhs.cacheRead + rhs.cacheRead
        )
    }
}

public struct UsageEvent: Equatable, Sendable, Codable, Identifiable {
    public var id: String { "\(timestamp.timeIntervalSince1970)-\(model)" }
    public let timestamp: Date
    public let model: String
    public let kind: BillingKind
    public let isTokenBased: Bool
    public let isHeadless: Bool
    public let tokens: TokenUsage?
    public let chargedCents: Double
    public let cursorTokenFee: Double?

    public init(
        timestamp: Date,
        model: String,
        kind: BillingKind,
        isTokenBased: Bool,
        isHeadless: Bool,
        tokens: TokenUsage?,
        chargedCents: Double,
        cursorTokenFee: Double? = nil
    ) {
        self.timestamp = timestamp
        self.model = model
        self.kind = kind
        self.isTokenBased = isTokenBased
        self.isHeadless = isHeadless
        self.tokens = tokens
        self.chargedCents = chargedCents
        self.cursorTokenFee = cursorTokenFee
    }
}

public struct UsageSummarySnapshot: Equatable, Sendable, Codable {
    public let cycleStart: Date
    public let cycleEnd: Date
    public let membershipType: String?
    public let limitType: String?
    public let teamPooledUsed: Int?
    public let teamPooledLimit: Int?
    public let teamPooledRemaining: Int?
    public let onDemandUsed: Double?
    public let individualOverallUsed: Int?

    public init(
        cycleStart: Date,
        cycleEnd: Date,
        membershipType: String? = nil,
        limitType: String? = nil,
        teamPooledUsed: Int? = nil,
        teamPooledLimit: Int? = nil,
        teamPooledRemaining: Int? = nil,
        onDemandUsed: Double? = nil,
        individualOverallUsed: Int? = nil
    ) {
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.membershipType = membershipType
        self.limitType = limitType
        self.teamPooledUsed = teamPooledUsed
        self.teamPooledLimit = teamPooledLimit
        self.teamPooledRemaining = teamPooledRemaining
        self.onDemandUsed = onDemandUsed
        self.individualOverallUsed = individualOverallUsed
    }
}

public struct ModelRollup: Equatable, Sendable, Identifiable {
    public var id: String { model }
    public let model: String
    public let tokens: TokenUsage
    public let chargedCents: Double
    public let requestCount: Int

    public init(model: String, tokens: TokenUsage, chargedCents: Double, requestCount: Int) {
        self.model = model
        self.tokens = tokens
        self.chargedCents = chargedCents
        self.requestCount = requestCount
    }

    /// Cost per million tokens, in cents. A rough "efficiency" signal — lower is
    /// cheaper per unit of work. `0` when no tokens were recorded.
    public var centsPerMillionTokens: Double {
        tokens.total > 0 ? chargedCents / Double(tokens.total) * 1_000_000 : 0
    }
}

/// Aggregated activity for one hour of the day (0–23), summed across all days in
/// the selected range. Used for the time-of-day heatmap.
public struct HourActivity: Equatable, Sendable, Identifiable {
    public var id: Int { hour }
    public let hour: Int
    public let requestCount: Int
    public let tokenTotal: Int

    public init(hour: Int, requestCount: Int, tokenTotal: Int) {
        self.hour = hour
        self.requestCount = requestCount
        self.tokenTotal = tokenTotal
    }
}

public struct UsageMetrics: Equatable, Sendable {
    public let tokens: TokenUsage
    public let chargedCents: Double
    public let eventCount: Int
    public let headlessCount: Int
    public let models: [ModelRollup]

    public init(
        tokens: TokenUsage,
        chargedCents: Double,
        eventCount: Int,
        headlessCount: Int = 0,
        models: [ModelRollup]
    ) {
        self.tokens = tokens
        self.chargedCents = chargedCents
        self.eventCount = eventCount
        self.headlessCount = headlessCount
        self.models = models
    }

    /// Interactive (non-background-agent) requests.
    public var interactiveCount: Int { max(eventCount - headlessCount, 0) }

    /// Average charge per request, in cents.
    public var averageCentsPerRequest: Double {
        eventCount > 0 ? chargedCents / Double(eventCount) : 0
    }

    /// Share of tokens that are cache reads (cheap, cached context) — a rough
    /// signal of how much work was served from cache vs fresh.
    public var cacheReadShare: Double {
        tokens.total > 0 ? Double(tokens.cacheRead) / Double(tokens.total) : 0
    }
}

public struct DailyTrendPoint: Equatable, Sendable, Identifiable {
    public var id: Date { day }
    public let day: Date
    public let tokenTotal: Int
    public let chargedCents: Double
    public let eventCount: Int

    public init(day: Date, tokenTotal: Int, chargedCents: Double, eventCount: Int) {
        self.day = day
        self.tokenTotal = tokenTotal
        self.chargedCents = chargedCents
        self.eventCount = eventCount
    }
}

public enum UsageRange: String, CaseIterable, Sendable, Identifiable {
    case today
    case sevenDays
    case thirtyDays
    case cycle

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: "Today"
        case .sevenDays: "7D"
        case .thirtyDays: "30D"
        case .cycle: "Cycle"
        }
    }

    public func interval(relativeTo now: Date, cycleStart: Date?) -> DateInterval {
        let end = now
        switch self {
        case .today:
            let start = Calendar.current.startOfDay(for: now)
            return DateInterval(start: start, end: end)
        case .sevenDays:
            return DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: end)
        case .thirtyDays:
            return DateInterval(start: now.addingTimeInterval(-30 * 86_400), end: end)
        case .cycle:
            let start = cycleStart ?? now.addingTimeInterval(-30 * 86_400)
            return DateInterval(start: start, end: end)
        }
    }
}

public enum MenuBarUnit: String, CaseIterable, Sendable, Codable, Identifiable {
    case tokens
    case dollars

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tokens: "Tokens"
        case .dollars: "Dollars"
        }
    }
}

public enum AppLoadState: Equatable, Sendable {
    case needsSetup
    case loading
    case loaded(lastUpdated: Date)
    case stale(lastUpdated: Date, reason: String)
    case error(String)
}

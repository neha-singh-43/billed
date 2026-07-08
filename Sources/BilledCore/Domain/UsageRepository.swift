import Foundation

public enum AuthSource: Equatable, Sendable {
    /// Token read live from the locally signed-in Cursor app.
    case localApp
    /// No usable session available (Cursor app not installed / signed in).
    case none
}

public struct AuthStatus: Equatable, Sendable {
    public let source: AuthSource
    public let email: String?
    public let membershipType: String?
    public let expiry: Date?

    public init(source: AuthSource, email: String? = nil, membershipType: String? = nil, expiry: Date? = nil) {
        self.source = source
        self.email = email
        self.membershipType = membershipType
        self.expiry = expiry
    }
}

public actor UsageRepository {
    private let localAuth: LocalAuthReader
    private let cache: LocalCache
    private var payload: UsageCachePayload
    private var refreshTask: Task<Void, Never>?

    public init(
        localAuth: LocalAuthReader = LocalAuthReader(),
        cache: LocalCache = LocalCache()
    ) {
        self.localAuth = localAuth
        self.cache = cache
        self.payload = cache.load()
    }

    public var summary: UsageSummarySnapshot? { payload.summary }
    public var events: [UsageEvent] { payload.events }
    public var lastUpdated: Date? { payload.lastSuccessfulFetch }
    public var isConfigured: Bool { resolveCookie() != nil }

    /// Describes which session the app will use, for display in the UI.
    public func authStatus() -> AuthStatus {
        if let auth = localAuth.read(), !auth.isExpired {
            return AuthStatus(
                source: .localApp,
                email: auth.email,
                membershipType: auth.membershipType,
                expiry: auth.expiry
            )
        }
        return AuthStatus(source: .none)
    }

    /// Resolves the cookie to authenticate with from the signed-in Cursor app's
    /// local token. Read fresh on each call and never persisted by this app.
    private func resolveCookie() -> String? {
        guard let auth = localAuth.read(), !auth.isExpired else { return nil }
        return auth.cookieValue
    }

    @discardableResult
    public func refresh(forceFullWindow: Bool = false) async throws -> Date {
        guard let cookie = resolveCookie() else { throw CursorAPIError.sessionExpired }
        let client = DashboardClient(sessionCookie: cookie)

        let summary = try await client.usageSummary()
        let now = Date()
        let since: Date
        if forceFullWindow || payload.events.isEmpty {
            since = now.addingTimeInterval(-Double(LocalCache.retentionDays) * 86_400)
        } else if let latest = payload.events.map(\.timestamp).max() {
            since = latest.addingTimeInterval(-86_400)
        } else {
            since = now.addingTimeInterval(-30 * 86_400)
        }

        let incoming = try await client.usageEvents(since: since, until: now)
        payload.summary = summary
        payload.events = cache.mergeEvents(incoming, existing: payload.events)
        payload.lastSuccessfulFetch = now
        try cache.save(payload)
        return now
    }

    public func startAutoRefresh(intervalMinutes: Int, onUpdate: @escaping @Sendable (Result<Date, Error>) -> Void) {
        refreshTask?.cancel()
        let seconds = max(intervalMinutes, 60) * 60
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { break }

                if self.isConfigured {
                    do {
                        let date = try await self.refresh()
                        onUpdate(.success(date))
                    } catch {
                        onUpdate(.failure(error))
                    }
                }
            }
        }
    }

    public func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func metrics(for range: UsageRange, now: Date = .now) -> UsageMetrics {
        let interval = range.interval(relativeTo: now, cycleStart: payload.summary?.cycleStart)
        return MetricsCalculator.metrics(for: payload.events, in: interval)
    }

    public func menuBarValue(unit: MenuBarUnit, range: UsageRange, now: Date = .now) -> String {
        let metrics = metrics(for: range, now: now)
        switch unit {
        case .tokens:
            return UsageFormatters.compactCount(metrics.tokens.total)
        case .dollars:
            return UsageFormatters.dollars(fromCents: metrics.chargedCents)
        }
    }
}

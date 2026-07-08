import Foundation
import SQLite3

public protocol ProviderDataSource: Sendable {
    var provider: ServiceProvider { get }
    func authStatus() async -> AuthStatus
    func isConfigured() async -> Bool
    func refresh(forceFullWindow: Bool) async throws -> Date
    func fetchSummary() async -> UsageSummarySnapshot?
    func fetchEvents() async -> [UsageEvent]
    func fetchLastUpdated() async -> Date?
}

// MARK: - Cursor

public actor CursorProvider: ProviderDataSource {
    private let repository: UsageRepository

    public init(repository: UsageRepository = UsageRepository()) {
        self.repository = repository
    }

    public nonisolated var provider: ServiceProvider { .cursor }

    public func authStatus() async -> AuthStatus {
        await repository.authStatus()
    }

    public func isConfigured() async -> Bool {
        await repository.isConfigured
    }

    public func refresh(forceFullWindow: Bool = false) async throws -> Date {
        try await repository.refresh(forceFullWindow: forceFullWindow)
    }

    public func fetchSummary() async -> UsageSummarySnapshot? {
        await repository.summary
    }

    public func fetchEvents() async -> [UsageEvent] {
        await repository.events
    }

    public func fetchLastUpdated() async -> Date? {
        await repository.lastUpdated
    }
}

// MARK: - Codex

public actor CodexProvider: ProviderDataSource {
    private let dbURL: URL
    private var _summary: UsageSummarySnapshot?
    private var _events: [UsageEvent] = []
    private var _lastUpdated: Date?
    private let authURL: URL

    public init(
        dbURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/state_5.sqlite"),
        authURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
    ) {
        self.dbURL = dbURL
        self.authURL = authURL
    }

    public nonisolated var provider: ServiceProvider { .codex }

    public func authStatus() async -> AuthStatus {
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            return AuthStatus(source: .none)
        }
        return AuthStatus(source: .localApp, email: "Codex CLI", membershipType: "individual")
    }

    public func isConfigured() async -> Bool {
        FileManager.default.fileExists(atPath: dbURL.path)
    }

    public func refresh(forceFullWindow _: Bool = false) async throws -> Date {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw ProviderError.databaseUnavailable
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = """
            SELECT model, model_provider, tokens_used, created_at, updated_at, source
            FROM threads ORDER BY created_at DESC;
            """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ProviderError.databaseUnavailable
        }
        defer { sqlite3_finalize(statement) }

        var events: [UsageEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let col = statement
            let model: String = {
                if sqlite3_column_type(col, 1) != SQLITE_NULL {
                    return String(cString: sqlite3_column_text(col, 1))
                }
                if sqlite3_column_type(col, 0) != SQLITE_NULL {
                    return String(cString: sqlite3_column_text(col, 0))
                }
                return "codex"
            }()
            let tokensUsed = Int(sqlite3_column_int64(col, 2))
            let createdAt = TimeInterval(sqlite3_column_int64(col, 3))
            let source = sqlite3_column_type(col, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(col, 5))
                : "unknown"

            let tokens = tokensUsed > 0
                ? TokenUsage(input: tokensUsed, output: 0, cacheWrite: 0, cacheRead: 0)
                : nil

            events.append(UsageEvent(
                timestamp: Date(timeIntervalSince1970: createdAt),
                model: model,
                kind: .includedInSubscription,
                isTokenBased: tokensUsed > 0,
                isHeadless: source == "cli",
                tokens: tokens,
                chargedCents: 0
            ))
        }

        let now = Date()
        let dates = events.map(\.timestamp)
        _summary = events.isEmpty
            ? nil
            : UsageSummarySnapshot(
                cycleStart: dates.min() ?? now,
                cycleEnd: dates.max() ?? now,
                membershipType: "Codex",
                limitType: "individual"
            )
        _events = events
        _lastUpdated = now
        return now
    }

    public func fetchSummary() async -> UsageSummarySnapshot? { _summary }
    public func fetchEvents() async -> [UsageEvent] { _events }
    public func fetchLastUpdated() async -> Date? { _lastUpdated }
}

// MARK: - Antigravity

public actor AntigravityProvider: ProviderDataSource {
    private let globalStateURL: URL
    private var _summary: UsageSummarySnapshot?
    private var _events: [UsageEvent] = []
    private var _lastUpdated: Date?

    public init(
        globalStateURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Antigravity IDE/User/globalStorage/state.vscdb")
    ) {
        self.globalStateURL = globalStateURL
    }

    public nonisolated var provider: ServiceProvider { .antigravity }

    public func authStatus() async -> AuthStatus {
        guard FileManager.default.fileExists(atPath: globalStateURL.path) else {
            return AuthStatus(source: .none)
        }

        let status = readGlobalStateValue(forKey: "antigravityUnifiedStateSync.userStatus")
        return AuthStatus(
            source: .localApp,
            email: Self.firstEmail(inBase64Payload: status),
            membershipType: Self.firstModelName(inBase64Payload: status)
        )
    }

    public func isConfigured() async -> Bool {
        FileManager.default.fileExists(atPath: globalStateURL.path)
    }

    public func refresh(forceFullWindow _: Bool = false) async throws -> Date {
        let now = Date()
        let events = try readFinishedAgentEvents()
        let dates = events.map(\.timestamp)
        let cycleStart = dates.min() ?? now
        let cycleEnd = max(dates.max() ?? now, now).addingTimeInterval(86400 * 30)
        _summary = UsageSummarySnapshot(
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            membershipType: "Antigravity",
            limitType: "individual"
        )
        _events = events
        _lastUpdated = now
        return now
    }

    public func fetchSummary() async -> UsageSummarySnapshot? { _summary }
    public func fetchEvents() async -> [UsageEvent] { _events }
    public func fetchLastUpdated() async -> Date? { _lastUpdated }

    private func readFinishedAgentEvents() throws -> [UsageEvent] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(globalStateURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw ProviderError.databaseUnavailable
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = """
            SELECT key
            FROM ItemTable
            WHERE key LIKE 'antigravity.notification.agent-finished-%'
            ORDER BY key DESC;
            """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ProviderError.databaseUnavailable
        }
        defer { sqlite3_finalize(statement) }

        var events: [UsageEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let key = Self.stringColumn(statement, 0),
                  let timestamp = Self.timestampFromFinishedNotificationKey(key)
            else { continue }

            events.append(UsageEvent(
                timestamp: timestamp,
                model: "Antigravity",
                kind: .includedInSubscription,
                isTokenBased: false,
                isHeadless: true,
                tokens: nil,
                chargedCents: 0
            ))
        }
        return events
    }

    private func readGlobalStateValue(forKey key: String) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(globalStateURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1;"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, key, -1, transient)

        return sqlite3_step(statement) == SQLITE_ROW ? Self.stringColumn(statement, 0) : nil
    }

    private nonisolated static func stringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index)
        else { return nil }
        return String(cString: text)
    }

    private nonisolated static func timestampFromFinishedNotificationKey(_ key: String) -> Date? {
        guard let rawTimestamp = key.split(separator: "-").last,
              let milliseconds = TimeInterval(rawTimestamp)
        else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1_000)
    }

    private nonisolated static func firstEmail(inBase64Payload payload: String?) -> String? {
        guard let text = decodedText(fromBase64Payload: payload) else { return nil }
        let pattern = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/.ignoresCase()
        return text.firstMatch(of: pattern).map { String($0.0) }
    }

    private nonisolated static func firstModelName(inBase64Payload payload: String?) -> String? {
        guard let text = decodedText(fromBase64Payload: payload) else { return nil }
        let candidates = ["Gemini 3.5 Flash", "Gemini 3.1 Pro", "Gemini 3.5 Pro", "Gemini"]
        return candidates.first { text.contains($0) }
    }

    private nonisolated static func decodedText(fromBase64Payload payload: String?) -> String? {
        guard let payload, let data = Data(base64Encoded: payload) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Opencode

public actor OpencodeProvider: ProviderDataSource {
    private let dbURL: URL
    private var _summary: UsageSummarySnapshot?
    private var _events: [UsageEvent] = []
    private var _lastUpdated: Date?

    public init(
        dbURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/opencode/opencode.db")
    ) {
        self.dbURL = dbURL
    }

    public nonisolated var provider: ServiceProvider { .opencode }

    public func authStatus() async -> AuthStatus {
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return AuthStatus(source: .none)
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return AuthStatus(source: .localApp, email: nil, membershipType: "local")
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = """
            SELECT email FROM account
            ORDER BY time_updated DESC
            LIMIT 1;
            """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return AuthStatus(source: .localApp, email: nil, membershipType: "local")
        }
        defer { sqlite3_finalize(statement) }

        let email = sqlite3_step(statement) == SQLITE_ROW ? Self.stringColumn(statement, 0) : nil
        return AuthStatus(source: .localApp, email: email, membershipType: "local")
    }

    public func isConfigured() async -> Bool {
        FileManager.default.fileExists(atPath: dbURL.path)
    }

    public func refresh(forceFullWindow _: Bool = false) async throws -> Date {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw ProviderError.databaseUnavailable
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = """
            SELECT model, agent, cost, tokens_input, tokens_output, tokens_cache_read,
                   tokens_cache_write, time_created, time_updated
            FROM session
            WHERE tokens_input > 0
               OR tokens_output > 0
               OR tokens_cache_read > 0
               OR tokens_cache_write > 0
               OR cost > 0
            ORDER BY time_created DESC;
            """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ProviderError.databaseUnavailable
        }
        defer { sqlite3_finalize(statement) }

        var events: [UsageEvent] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let model = Self.opencodeModelName(from: Self.stringColumn(statement, 0))
            let agent = Self.stringColumn(statement, 1)
            let costDollars = sqlite3_column_double(statement, 2)
            let tokens = TokenUsage(
                input: Int(sqlite3_column_int64(statement, 3)),
                output: Int(sqlite3_column_int64(statement, 4)),
                cacheWrite: Int(sqlite3_column_int64(statement, 6)),
                cacheRead: Int(sqlite3_column_int64(statement, 5))
            )
            let createdAtMilliseconds = sqlite3_column_int64(statement, 7)
            let updatedAtMilliseconds = sqlite3_column_int64(statement, 8)
            let timestampMilliseconds = updatedAtMilliseconds > 0 ? updatedAtMilliseconds : createdAtMilliseconds

            events.append(UsageEvent(
                timestamp: Date(timeIntervalSince1970: TimeInterval(timestampMilliseconds) / 1_000),
                model: model,
                kind: costDollars > 0 ? .usageBased : .includedInSubscription,
                isTokenBased: tokens.total > 0,
                isHeadless: agent != nil,
                tokens: tokens.total > 0 ? tokens : nil,
                chargedCents: costDollars * 100
            ))
        }

        let now = Date()
        let dates = events.map(\.timestamp)
        let cycleStart = dates.min() ?? now
        let cycleEnd = max(dates.max() ?? now, now).addingTimeInterval(86400 * 30)
        _summary = UsageSummarySnapshot(
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            membershipType: "Opencode",
            limitType: "individual"
        )
        _events = events
        _lastUpdated = now
        return now
    }

    public func fetchSummary() async -> UsageSummarySnapshot? { _summary }
    public func fetchEvents() async -> [UsageEvent] { _events }
    public func fetchLastUpdated() async -> Date? { _lastUpdated }

    private nonisolated static func stringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index)
        else { return nil }
        return String(cString: text)
    }

    private nonisolated static func opencodeModelName(from json: String?) -> String {
        guard let json,
              let data = json.data(using: .utf8),
              let model = try? JSONDecoder().decode(OpencodeModel.self, from: data)
        else { return "opencode" }

        if let provider = model.providerID, !provider.isEmpty {
            return "\(provider)/\(model.id)"
        }
        return model.id
    }

    private struct OpencodeModel: Decodable {
        let id: String
        let providerID: String?
    }
}

// MARK: - Claude

public actor ClaudeProvider: ProviderDataSource {
    private var _summary: UsageSummarySnapshot?
    private var _events: [UsageEvent] = []
    private var _lastUpdated: Date?

    public init() {}

    public nonisolated var provider: ServiceProvider { .claude }

    public func authStatus() async -> AuthStatus {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude")
        guard FileManager.default.fileExists(atPath: claudeDir.path) else {
            return AuthStatus(source: .none)
        }
        return AuthStatus(source: .localApp, email: nil, membershipType: nil)
    }

    public func isConfigured() async -> Bool {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude")
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: claudeDir.path, isDirectory: &isDir) && isDir.boolValue
    }

    public func refresh(forceFullWindow _: Bool = false) async throws -> Date {
        let now = Date()
        _events = []
        _summary = UsageSummarySnapshot(
            cycleStart: now,
            cycleEnd: now.addingTimeInterval(86400 * 30),
            membershipType: "Claude",
            limitType: "individual"
        )
        _lastUpdated = now
        return now
    }

    public func fetchSummary() async -> UsageSummarySnapshot? { _summary }
    public func fetchEvents() async -> [UsageEvent] { _events }
    public func fetchLastUpdated() async -> Date? { _lastUpdated }
}

// MARK: - Error

public enum ProviderError: Error, LocalizedError {
    case databaseUnavailable
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .databaseUnavailable: "Local database not found"
        case .notConfigured: "Provider not configured"
        }
    }
}

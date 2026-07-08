import Foundation
import SQLite3

/// Session derived from the locally signed-in Cursor app.
public struct LocalAuth: Sendable, Equatable {
    /// The `WorkosCursorSessionToken` cookie value: `<userId>::<jwt>`.
    public let cookieValue: String
    public let email: String?
    public let membershipType: String?
    public let expiry: Date?

    public init(cookieValue: String, email: String?, membershipType: String?, expiry: Date?) {
        self.cookieValue = cookieValue
        self.email = email
        self.membershipType = membershipType
        self.expiry = expiry
    }

    public var isExpired: Bool {
        guard let expiry else { return false }
        return expiry <= Date()
    }
}

/// Reads the Cursor IDE's local auth token so we can monitor usage without the
/// user pasting a cookie. The token lives in the app's `state.vscdb` SQLite
/// store under the key `cursorAuth/accessToken` (a JWT). The dashboard API wants
/// the cookie as `<userId>::<jwt>`, where `userId` is the JWT `sub` minus its
/// `auth0|` prefix.
///
/// The DB is opened read-only and immutable so we never lock or mutate the file
/// while Cursor has it open.
public struct LocalAuthReader: Sendable {
    public let databaseURL: URL

    public static var defaultDatabaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    public init(databaseURL: URL = LocalAuthReader.defaultDatabaseURL) {
        self.databaseURL = databaseURL
    }

    /// Whether the local Cursor database file exists (cheap; does not open it).
    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: databaseURL.path)
    }

    public func read() -> LocalAuth? {
        guard isAvailable else { return nil }
        guard let token = value(forKey: "cursorAuth/accessToken"), !token.isEmpty else { return nil }
        guard let claims = Self.decodeJWTClaims(token),
              let sub = claims["sub"] as? String else { return nil }

        let userId = sub.split(separator: "|").last.map(String.init) ?? sub
        guard !userId.isEmpty else { return nil }

        return LocalAuth(
            cookieValue: "\(userId)::\(token)",
            email: value(forKey: "cursorAuth/cachedEmail"),
            membershipType: value(forKey: "cursorAuth/stripeMembershipType"),
            expiry: Self.expiry(from: claims)
        )
    }

    // MARK: - JWT

    public static func decodeJWTClaims(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data),
              let claims = object as? [String: Any] else { return nil }
        return claims
    }

    private static func expiry(from claims: [String: Any]) -> Date? {
        if let exp = claims["exp"] as? Double { return Date(timeIntervalSince1970: exp) }
        if let exp = claims["exp"] as? Int { return Date(timeIntervalSince1970: Double(exp)) }
        return nil
    }

    // MARK: - SQLite

    private static let uriAllowed = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/._-~"
    )

    private func value(forKey key: String) -> String? {
        let encodedPath = databaseURL.path.addingPercentEncoding(withAllowedCharacters: Self.uriAllowed)
            ?? databaseURL.path
        let uri = "file:\(encodedPath)?immutable=1"

        var db: OpaquePointer?
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return nil
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1;"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }

        // SQLITE_TRANSIENT: tell SQLite to copy the bound string immediately.
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, key, -1, transient)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let bytes = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: bytes)
    }
}

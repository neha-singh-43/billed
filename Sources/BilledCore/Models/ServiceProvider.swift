import Foundation

public enum ServiceProvider: String, CaseIterable, Identifiable, Sendable {
    case cursor
    case codex
    case antigravity
    case opencode
    case claude

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cursor: "Cursor"
        case .codex: "Codex"
        case .antigravity: "Antigravity"
        case .opencode: "Opencode"
        case .claude: "Claude"
        }
    }

    public var iconName: String {
        switch self {
        case .cursor: "cursorarrow"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .antigravity: "sparkles"
        case .opencode: "terminal"
        case .claude: "brain"
        }
    }

    public var hasRealData: Bool {
        switch self {
        case .cursor, .codex, .antigravity, .opencode: true
        case .claude: false
        }
    }

    public var settingsDescription: String {
        switch self {
        case .cursor:
            "Reads Cursor dashboard usage with auth from the local Cursor app."
        case .codex:
            "Reads local Codex CLI thread usage from the Codex state database."
        case .antigravity:
            "Reads Antigravity IDE local agent activity from the global state database."
        case .opencode:
            "Shows Opencode local usage once the config or CLI install is detected."
        case .claude:
            "Detects the Claude desktop app. Usage import is not wired yet."
        }
    }

    public var settingsPaths: [String] {
        switch self {
        case .cursor:
            [
                "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb",
                "cursorAuth/accessToken"
            ]
        case .codex:
            [
                "~/.codex/state_5.sqlite",
                "~/.codex/auth.json"
            ]
        case .antigravity:
            [
                "~/Library/Application Support/Antigravity IDE/User/globalStorage/state.vscdb",
                "~/.gemini/antigravity",
                "~/Library/Application Support/Antigravity IDE"
            ]
        case .opencode:
            [
                "~/.local/share/opencode/opencode.db",
                "~/.config/opencode",
                "opencode CLI on PATH"
            ]
        case .claude:
            [
                "~/Library/Application Support/Claude"
            ]
        }
    }

    public var isAvailable: Bool {
        switch self {
        case .cursor: LocalAuthReader().isAvailable
        case .codex: Self.codexIsAvailable
        case .antigravity: Self.antigravityIsAvailable
        case .opencode: Self.opencodeIsAvailable
        case .claude: Self.claudeIsAvailable
        }
    }

    public func makeDataSource() -> any ProviderDataSource {
        switch self {
        case .cursor: CursorProvider()
        case .codex: CodexProvider()
        case .antigravity: AntigravityProvider()
        case .opencode: OpencodeProvider()
        case .claude: ClaudeProvider()
        }
    }

    private static var codexIsAvailable: Bool {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: codexDir.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        let dbURL = codexDir.appendingPathComponent("state_5.sqlite")
        return FileManager.default.fileExists(atPath: dbURL.path)
    }

    private static var antigravityIsAvailable: Bool {
        let globalState = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Antigravity IDE/User/globalStorage/state.vscdb")
        if FileManager.default.fileExists(atPath: globalState.path) { return true }
        let stateDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/antigravity")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: stateDir.path, isDirectory: &isDir), isDir.boolValue {
            return true
        }
        let appDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Antigravity IDE")
        return fileExistsAndIsDirectory(appDir)
    }

    private static var opencodeIsAvailable: Bool {
        let dbURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/opencode/opencode.db")
        if FileManager.default.fileExists(atPath: dbURL.path) { return true }
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opencode")
        if fileExistsAndIsDirectory(configDir) { return true }
        return (try? which("opencode")) != nil
    }

    private static var claudeIsAvailable: Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude")
        return fileExistsAndIsDirectory(url)
    }

    private static func fileExistsAndIsDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func which(_ command: String) throws -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == false ? output : nil
    }
}

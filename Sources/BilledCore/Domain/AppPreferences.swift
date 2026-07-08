import Foundation

public struct AppPreferences {
    private enum Key {
        static let menuBarUnit = "menuBarUnit"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let launchAtLogin = "launchAtLogin"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var menuBarUnit: MenuBarUnit {
        get {
            guard let raw = defaults.string(forKey: Key.menuBarUnit),
                  let value = MenuBarUnit(rawValue: raw) else { return .dollars }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: Key.menuBarUnit) }
    }

    public var refreshIntervalMinutes: Int {
        get {
            let value = defaults.integer(forKey: Key.refreshIntervalMinutes)
            return value >= 60 ? value : 60
        }
        set { defaults.set(max(60, newValue), forKey: Key.refreshIntervalMinutes) }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }
}

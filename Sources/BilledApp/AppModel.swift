import BilledCore
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppModel {
    var loadState: AppLoadState = .needsSetup
    var selectedRange: UsageRange = .cycle
    var showSettings = false
    var showAllModels = false
    var modelSort: ModelSort = .tokens
    var trendMetric: TrendMetric = .tokens
    var selectedProvider: ServiceProvider = .cursor {
        didSet {
            if oldValue != selectedProvider {
                let provider = selectedProvider
                Task { await providerDidChange(to: provider) }
            }
        }
    }

    var summary: UsageSummarySnapshot?
    var events: [UsageEvent] = []
    var menuBarLabel = "—"
    var isRefreshing = false
    var authStatus = AuthStatus(source: .none)

    var preferences = AppPreferences()
    let configManager = ConfigManager()
    private let cursorRepository = UsageRepository()
    private var dataSources: [ServiceProvider: any ProviderDataSource] = [:]

    private var activeDataSource: (any ProviderDataSource)? {
        dataSources[selectedProvider]
    }

    enum ModelSort: String, CaseIterable, Identifiable {
        case tokens, cost, requests, efficiency
        var id: String { rawValue }
        var title: String {
            switch self {
            case .tokens: "Tokens"
            case .cost: "Cost"
            case .requests: "Requests"
            case .efficiency: "$ / Mtok"
            }
        }
    }

    enum TrendMetric: String, CaseIterable, Identifiable {
        case tokens, cost
        var id: String { rawValue }
        var title: String {
            switch self {
            case .tokens: "Tokens"
            case .cost: "Cost"
            }
        }
    }

    init() {
        dataSources[.cursor] = CursorProvider(repository: cursorRepository)
        dataSources[.codex] = CodexProvider()
        dataSources[.antigravity] = AntigravityProvider()
        dataSources[.opencode] = OpencodeProvider()
        dataSources[.claude] = ClaudeProvider()
        Task { await bootstrap() }
    }

#if DEBUG
    /// Preview-only initialiser that skips all async data fetching so the
    /// Xcode canvas can render synchronously with injected sample data.
    init(_preview: Void) {
        // Intentionally skip `Task { await bootstrap() }`
    }
#endif

    func bootstrap() async {
        let provider = selectedProvider
        guard let source = dataSources[provider] else {
            loadState = .needsSetup
            menuBarLabel = "!"
            return
        }
        clearUsageState()
        authStatus = await source.authStatus()
        let configured = await source.isConfigured()
        guard selectedProvider == provider else { return }
        if !configured {
            loadState = .needsSetup
            menuBarLabel = "!"
            return
        }
        applyUsageState(summary: await source.fetchSummary(), events: await source.fetchEvents())
        await updateMenuBarLabel()
        if let last = await source.fetchLastUpdated() {
            guard selectedProvider == provider else { return }
            loadState = .loaded(lastUpdated: last)
        }
        if provider == .cursor, selectedProvider == provider {
            startCursorAutoRefresh()
        }
        await refresh(force: events.isEmpty)
    }

    func providerDidChange(to provider: ServiceProvider) async {
        stopAutoRefresh()
        isRefreshing = false
        clearUsageState()
        guard let source = dataSources[provider] else { return }
        authStatus = await source.authStatus()
        let configured = await source.isConfigured()
        guard selectedProvider == provider else { return }
        if !configured {
            loadState = .needsSetup
            return
        }
        applyUsageState(summary: await source.fetchSummary(), events: await source.fetchEvents())
        await updateMenuBarLabel()
        if let last = await source.fetchLastUpdated() {
            guard selectedProvider == provider else { return }
            loadState = .loaded(lastUpdated: last)
        } else {
            await refresh(provider: provider, force: true)
        }
        if provider == .cursor, selectedProvider == provider {
            startCursorAutoRefresh()
        }
    }

    var currentMetrics: UsageMetrics {
        let interval = selectedRange.interval(relativeTo: .now, cycleStart: summary?.cycleStart)
        return MetricsCalculator.metrics(for: events, in: interval)
    }

    var dailyTrend: [DailyTrendPoint] {
        let interval = selectedRange.interval(relativeTo: .now, cycleStart: summary?.cycleStart)
        return MetricsCalculator.dailyTrend(for: events, in: interval)
    }

    var busiestDay: DailyTrendPoint? {
        MetricsCalculator.busiestDay(in: dailyTrend)
    }

    var hourlyActivity: [HourActivity] {
        let interval = selectedRange.interval(relativeTo: .now, cycleStart: summary?.cycleStart)
        return MetricsCalculator.hourOfDayActivity(for: events, in: interval)
    }

    var teamPoolSummary: String? {
        guard let summary, summary.limitType == "team",
              let used = summary.teamPooledUsed,
              let limit = summary.teamPooledLimit, limit > 0
        else { return nil }
        let pct = Int(Double(used) / Double(limit) * 100)
        return "Team pool \(pct)% used (\(UsageFormatters.compactCount(used)) / \(UsageFormatters.compactCount(limit)))"
    }

    var sortedModels: [ModelRollup] {
        let models = currentMetrics.models
        switch modelSort {
        case .tokens:
            return models.sorted { $0.tokens.total > $1.tokens.total }
        case .cost:
            return models.sorted { $0.chargedCents > $1.chargedCents }
        case .requests:
            return models.sorted { $0.requestCount > $1.requestCount }
        case .efficiency:
            return models.sorted { $0.centsPerMillionTokens < $1.centsPerMillionTokens }
        }
    }

    var projectedCycleSpend: Double? {
        guard selectedRange == .cycle, let summary else { return nil }
        let charged = MetricsCalculator.spendThisCycle(from: events, cycleStart: summary.cycleStart)
        return MetricsCalculator.projectedCycleSpend(
            chargedSoFar: charged,
            cycleStart: summary.cycleStart,
            cycleEnd: summary.cycleEnd
        )
    }

    func refresh(force: Bool = false) async {
        await refresh(provider: selectedProvider, force: force)
    }

    func refresh(provider: ServiceProvider, force: Bool = false) async {
        guard let source = dataSources[provider] else {
            loadState = .needsSetup
            menuBarLabel = "!"
            return
        }
        guard await source.isConfigured() else {
            guard selectedProvider == provider else { return }
            loadState = .needsSetup
            menuBarLabel = "!"
            return
        }
        guard selectedProvider == provider else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let updated = try await source.refresh(forceFullWindow: force)
            guard selectedProvider == provider else { return }
            applyUsageState(summary: await source.fetchSummary(), events: await source.fetchEvents())
            await updateMenuBarLabel()
            loadState = .loaded(lastUpdated: updated)
        } catch let error as CursorAPIError {
            guard selectedProvider == provider else { return }
            applyUsageState(summary: await source.fetchSummary(), events: await source.fetchEvents())
            await updateMenuBarLabel()
            if let last = await source.fetchLastUpdated(), !events.isEmpty {
                loadState = .stale(lastUpdated: last, reason: error.localizedDescription)
            } else {
                loadState = .error(error.localizedDescription)
                menuBarLabel = "!"
            }
        } catch {
            guard selectedProvider == provider else { return }
            if let last = await source.fetchLastUpdated(), !events.isEmpty {
                loadState = .stale(lastUpdated: last, reason: error.localizedDescription)
            } else {
                loadState = .error(error.localizedDescription)
                menuBarLabel = "!"
            }
        }
    }

    func menuBarMetricChanged() async {
        await updateMenuBarLabel()
    }

    func isProviderEnabled(_ provider: ServiceProvider) -> Bool {
        configManager.isEnabled(provider)
    }

    func setProviderEnabled(_ provider: ServiceProvider, _ enabled: Bool) {
        configManager.setEnabled(provider, enabled)
        Task { await updateMenuBarLabel() }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        preferences.launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loadState = .error("Launch at login failed: \(error.localizedDescription)")
        }
    }

    private var cursorProvider: CursorProvider? {
        dataSources[.cursor] as? CursorProvider
    }

    private func startCursorAutoRefresh() {
        guard cursorProvider != nil else { return }
        Task {
            await cursorRepository.startAutoRefresh(intervalMinutes: preferences.refreshIntervalMinutes) { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.selectedProvider == .cursor else { return }
                    switch result {
                    case .success(let date):
                        self.summary = await self.cursorRepository.summary
                        self.events = await self.cursorRepository.events
                        await self.updateMenuBarLabel()
                        self.loadState = .loaded(lastUpdated: date)
                    case .failure(let error):
                        if let last = await self.cursorRepository.lastUpdated, !self.events.isEmpty {
                            self.loadState = .stale(lastUpdated: last, reason: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    private func stopAutoRefresh() {
        Task { await cursorRepository.stopAutoRefresh() }
    }

    private func clearUsageState() {
        summary = nil
        events = []
        loadState = .loading
    }

    private func applyUsageState(summary: UsageSummarySnapshot?, events: [UsageEvent]) {
        self.summary = summary
        self.events = events
    }

    private func updateMenuBarLabel() async {
        // Use a unified interval across all providers. For .cycle we fall back to
        // 30 days since different providers have different billing cycles.
        let interval = selectedRange.interval(relativeTo: .now, cycleStart: nil)
        var totalCents = 0.0
        var totalTokens = 0

        for (provider, source) in dataSources {
            guard configManager.isEnabled(provider), await source.isConfigured() else { continue }
            let events = await source.fetchEvents()
            for event in events where interval.contains(event.timestamp) {
                totalCents += event.chargedCents
                if let tokens = event.tokens {
                    totalTokens += tokens.total
                }
            }
        }

        switch preferences.menuBarUnit {
        case .tokens:
            menuBarLabel = UsageFormatters.compactCount(totalTokens)
        case .dollars:
            menuBarLabel = UsageFormatters.dollars(fromCents: totalCents)
        }
    }
}

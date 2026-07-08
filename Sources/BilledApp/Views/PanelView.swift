import AppKit
import BilledCore
import SwiftUI

struct PanelView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.showSettings {
                SettingsView(model: model)
            } else {
                mainPanel
            }
        }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if model.selectedProvider.hasRealData {
                usageContent
            } else {
                providerPlaceholder
            }
            Divider()
            footer
        }
    }

    private var usageContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if case .needsSetup = model.loadState {
                    SetupView(model: model)
                } else {
                    statusBanner
                    metricsSection
                    if let pool = model.teamPoolSummary {
                        teamPoolBanner(pool)
                    }
                    tokenSplitSection
                    activitySection
                    trendSection
                    hourHeatmapSection
                    modelsSection
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
              HStack {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.preferences.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                .controlSize(.small)
                Spacer()
                Button {
                    model.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .padding(.trailing, 6)
                .buttonStyle(.plain)
                .help("Settings…")
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .help("Quit")
            }
            Picker("Range", selection: $model.selectedRange) {
                ForEach(UsageRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Usage range")
            .onChange(of: model.selectedRange) { _, _ in
                Task { await model.menuBarMetricChanged() }
            }
            lastUpdatedText
        }
        .padding(16)
    }

    private var providerTabs: some View {
        HStack(spacing: 2) {
            ForEach(ServiceProvider.allCases) { provider in
                let isEnabled = model.isProviderEnabled(provider)
                Button {
                    model.selectedProvider = provider
                } label: {
                    HStack(spacing: 3) {
                        Text(provider.displayName)
                            .font(.system(size: 10, weight: model.selectedProvider == provider ? .semibold : .regular))
                            .lineLimit(1)
                        if !isEnabled {
                            Image(systemName: "line.diagonal")
                                .font(.system(size: 7))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .background(
                    model.selectedProvider == provider
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .foregroundStyle(
                    provider.isAvailable
                        ? (model.selectedProvider == provider ? .primary : .secondary)
                        : .tertiary
                )
                .opacity(isEnabled || model.selectedProvider == provider ? 1 : 0.5)
                .disabled(!provider.isAvailable)
                .help(provider.isAvailable
                    ? (isEnabled ? "\(provider.displayName)" : "\(provider.displayName) · disabled in settings")
                    : "\(provider.displayName) not available")
            }
            Spacer(minLength: 4)
            if model.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh usage data")
                .accessibilityLabel("Refresh")
            }
        }
    }

    private var providerPlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: model.selectedProvider.iconName)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(model.selectedProvider.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(placeholderMessage)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderMessage: String {
        let name = model.selectedProvider.displayName
        if model.selectedProvider.isAvailable {
            return "\(name) is installed but usage data integration\nneeds local data source configuration."
        }
        return "\(name) is not installed.\nInstall and sign in to track usage."
    }

    @ViewBuilder
    private var lastUpdatedText: some View {
        switch model.loadState {
        case .loaded(let date):
            Text("Updated \(UsageFormatters.relativeTime(since: date))")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .stale(let date, _):
            Text("Cached · \(UsageFormatters.relativeTime(since: date))")
                .font(.caption)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    private func teamPoolBanner(_ text: String) -> some View {
        Label(text, systemImage: "person.3.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch model.loadState {
        case .stale(_, let reason):
            Label(reason, systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        case .loading:
            HStack {
                ProgressView()
                Text("Loading usage…")
                    .font(.caption)
            }
        default:
            EmptyView()
        }
    }

    private var metricsSection: some View {
        let metrics = model.currentMetrics
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MetricCard(
                    title: "Tokens",
                    value: UsageFormatters.compactCount(metrics.tokens.total),
                    subtitle: "\(metrics.eventCount) requests"
                )
                MetricCard(
                    title: "Cost",
                    value: UsageFormatters.dollars(fromCents: metrics.chargedCents),
                    subtitle: costSubtitle
                )
            }
            if let summary = model.summary, model.selectedRange == .cycle {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Billing cycle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(cycleText(summary))
                            .font(.caption2)
                    }
                    Spacer()
                    if let projected = model.projectedCycleSpend {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Projected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(UsageFormatters.dollars(fromCents: projected))
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Projected cycle spend \(UsageFormatters.dollars(fromCents: projected))")
                    }
                }
            }
        }
    }

    private var costSubtitle: String {
        if let summary = model.summary, let onDemand = summary.onDemandUsed {
            return "On-demand: \(UsageFormatters.dollars(fromCents: onDemand))"
        }
        return "Sum of chargedCents"
    }

    private func cycleText(_ summary: UsageSummarySnapshot) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "\(df.string(from: summary.cycleStart)) – \(df.string(from: summary.cycleEnd))"
    }

    private var tokenSplitSection: some View {
        let t = model.currentMetrics.tokens
        let total = max(t.total, 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Token split")
                .font(.subheadline.weight(.semibold))
            TokenSplitBar(tokens: t)
                .accessibilityLabel("Token split: input \(UsageFormatters.percent(t.input, of: total)), output \(UsageFormatters.percent(t.output, of: total)), cache write \(UsageFormatters.percent(t.cacheWrite, of: total)), cache read \(UsageFormatters.percent(t.cacheRead, of: total))")
            HStack(spacing: 12) {
                splitLegend("In", t.input, total, .blue)
                splitLegend("Out", t.output, total, .green)
                splitLegend("Cache W", t.cacheWrite, total, .orange)
                splitLegend("Cache R", t.cacheRead, total, .purple)
            }
            .font(.caption2)
        }
    }

    private func splitLegend(_ label: String, _ value: Int, _ total: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(UsageFormatters.percent(value, of: total))")
        }
        .accessibilityHidden(true)
    }

    private var activitySection: some View {
        let metrics = model.currentMetrics
        return VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.subheadline.weight(.semibold))
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                StatTile(
                    label: "Requests",
                    value: "\(metrics.eventCount)",
                    detail: "\(metrics.interactiveCount) interactive"
                )
                StatTile(
                    label: "Background agents",
                    value: "\(metrics.headlessCount)",
                    detail: "headless requests"
                )
                StatTile(
                    label: "Avg / request",
                    value: UsageFormatters.dollars(fromCents: metrics.averageCentsPerRequest),
                    detail: "mean charge"
                )
                StatTile(
                    label: "Cache reads",
                    value: UsageFormatters.percent(metrics.tokens.cacheRead, of: max(metrics.tokens.total, 1)),
                    detail: "of all tokens"
                )
                if let busiest = model.busiestDay {
                    StatTile(
                        label: "Busiest day",
                        value: busiestDayText(busiest.day),
                        detail: "\(UsageFormatters.compactCount(busiest.tokenTotal)) tokens"
                    )
                }
            }
        }
    }

    private func busiestDayText(_ day: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM"
        return df.string(from: day)
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Trend metric", selection: $model.trendMetric) {
                    ForEach(AppModel.TrendMetric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)
            }
            DailyTrendChartView(points: model.dailyTrend, metric: model.trendMetric)
        }
    }

    private var hourHeatmapSection: some View {
        let activity = model.hourlyActivity
        let peak = activity.map(\.requestCount).max() ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("Time of day")
                .font(.subheadline.weight(.semibold))
            HourHeatmapView(activity: activity, peak: peak)
        }
    }

    private var modelsSection: some View {
        let sorted = model.sortedModels
        let maxTokens = sorted.first?.tokens.total ?? 1
        let maxCost = sorted.map(\.chargedCents).max() ?? 1
        let maxRequests = sorted.map(\.requestCount).max() ?? 1
        let maxEfficiency = sorted.map(\.centsPerMillionTokens).max() ?? 1

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Models")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Sort", selection: $model.modelSort) {
                    ForEach(AppModel.ModelSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }
            let models = model.showAllModels ? sorted : Array(sorted.prefix(5))
            if models.isEmpty {
                Text("No usage in this range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(models) { rollup in
                    ModelRowView(
                        rollup: rollup,
                        sort: model.modelSort,
                        maxTokens: maxTokens,
                        maxCost: maxCost,
                        maxRequests: maxRequests,
                        maxEfficiency: maxEfficiency
                    )
                }
                if sorted.count > 5 {
                    Button(model.showAllModels ? "Show less" : "Show all (\(sorted.count))") {
                        model.showAllModels.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            providerTabs
        }
        .padding(12)
        .font(.caption)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value). \(subtitle)")
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value), \(detail)")
    }
}

struct TokenSplitBar: View {
    let tokens: TokenUsage

    var body: some View {
        let total = max(tokens.total, 1)
        GeometryReader { geo in
            HStack(spacing: 1) {
                barSegment(tokens.input, total, .blue, width: geo.size.width)
                barSegment(tokens.output, total, .green, width: geo.size.width)
                barSegment(tokens.cacheWrite, total, .orange, width: geo.size.width)
                barSegment(tokens.cacheRead, total, .purple, width: geo.size.width)
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func barSegment(_ value: Int, _ total: Int, _ color: Color, width: CGFloat) -> some View {
        color
            .frame(width: max(width * CGFloat(value) / CGFloat(total), value > 0 ? 2 : 0))
    }
}

struct ModelRowView: View {
    let rollup: ModelRollup
    let sort: AppModel.ModelSort
    let maxTokens: Int
    let maxCost: Double
    let maxRequests: Int
    let maxEfficiency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rollup.model)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(width: geo.size.width * barFraction)
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rollup.model), \(detail)")
    }

    private var detail: String {
        switch sort {
        case .tokens: UsageFormatters.compactCount(rollup.tokens.total)
        case .cost: UsageFormatters.dollars(fromCents: rollup.chargedCents)
        case .requests: "\(rollup.requestCount) requests"
        case .efficiency: "\(UsageFormatters.dollars(fromCents: rollup.centsPerMillionTokens))/Mtok"
        }
    }

    private var barFraction: CGFloat {
        switch sort {
        case .tokens:
            guard maxTokens > 0 else { return 0 }
            return CGFloat(rollup.tokens.total) / CGFloat(maxTokens)
        case .cost:
            guard maxCost > 0 else { return 0 }
            return CGFloat(rollup.chargedCents / maxCost)
        case .requests:
            guard maxRequests > 0 else { return 0 }
            return CGFloat(rollup.requestCount) / CGFloat(maxRequests)
        case .efficiency:
            guard maxEfficiency > 0 else { return 0 }
            return CGFloat(rollup.centsPerMillionTokens / maxEfficiency)
        }
    }
}

struct HourHeatmapView: View {
    let activity: [HourActivity]
    let peak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let spacing: CGFloat = 2
                let cellWidth = (geo.size.width - spacing * 23) / 24
                HStack(spacing: spacing) {
                    ForEach(activity) { hour in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: hour.requestCount))
                            .frame(width: max(cellWidth, 1), height: 18)
                            .accessibilityLabel("\(hourLabel(hour.hour)): \(hour.requestCount) requests")
                    }
                }
            }
            .frame(height: 18)
            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18], id: \.self) { mark in
                    Text(hourLabel(mark))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Requests by hour of day")
    }

    private func color(for count: Int) -> Color {
        guard peak > 0, count > 0 else { return Color.secondary.opacity(0.12) }
        let intensity = 0.2 + 0.8 * (Double(count) / Double(peak))
        return Color.accentColor.opacity(intensity)
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12a"
        case 12: "12p"
        case let h where h < 12: "\(h)a"
        default: "\(hour - 12)p"
        }
    }
}

#if DEBUG
#Preview("Panel – loaded") {
    PanelView(model: AppModel.sample())
        .frame(width: 360, height: 560)
}

#Preview("Panel – settings") {
    let m = AppModel.sample()
    m.showSettings = true
    return PanelView(model: m)
        .frame(width: 360, height: 560)
}
#endif

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
            if model.selectedProvider.hasRealData {
                usageContent
            } else {
                providerPlaceholder
            }
            footer
        }
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.08),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
                    trendSection
                    activitySection
                    bottomAnalyticsGrid
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                appIdentity
                Spacer()
                Button {
                    model.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .glassButtonBackground()
                }
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Settings")
            }
            providerTabs
            HStack(spacing: 10) {
                rangePicker
                refreshButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var appIdentity: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.88))
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
            }
            .frame(width: 40, height: 40)
            .shadow(color: .black.opacity(0.16), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("Billed")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                lastUpdatedText
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var refreshButton: some View {
        Group {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
            } else {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .glassButtonBackground()
                }
                .buttonStyle(.plain)
                .help("Refresh usage data")
                .accessibilityLabel("Refresh")
            }
        }
    }

    private var rangePicker: some View {
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
    }

    private var providerTabs: some View {
        HStack(spacing: 0) {
            ForEach(ServiceProvider.allCases) { provider in
                providerTab(provider)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
    }

    private func providerTab(_ provider: ServiceProvider) -> some View {
        let isEnabled = model.isProviderEnabled(provider)
        let isSelected = model.selectedProvider == provider
        let titleWeight: Font.Weight = isSelected ? .semibold : .medium
        let foreground: Color = provider.isAvailable ? (isSelected ? .white : .primary) : .secondary
        let helpText = provider.isAvailable
            ? (isEnabled ? provider.displayName : "\(provider.displayName) · disabled in settings")
            : "\(provider.displayName) not available"

        return Button {
            model.selectedProvider = provider
        } label: {
            HStack(spacing: 5) {
                Text(provider.displayName)
                    .font(.system(size: 12, weight: titleWeight))
                    .lineLimit(1)
                if !isEnabled {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: 8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(foreground)
        .opacity(isEnabled || isSelected ? 1 : 0.5)
        .disabled(!provider.isAvailable)
        .help(helpText)
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
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Current usage")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(UsageFormatters.compactCount(metrics.tokens.total))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("tokens")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                HStack(spacing: 8) {
                    SummaryChip(
                        label: "Tokens",
                        value: UsageFormatters.compactCount(metrics.tokens.total),
                        detail: "tokens",
                        systemImage: "arrow.triangle.2.circlepath",
                        color: .blue
                    )
                    SummaryChip(
                        label: "Cost",
                        value: UsageFormatters.dollars(fromCents: metrics.chargedCents),
                        detail: "Cost",
                        systemImage: "dollarsign",
                        color: .green
                    )
                    SummaryChip(
                        label: "Requests",
                        value: "\(metrics.eventCount)",
                        detail: "Requests",
                        systemImage: "tray.full",
                        color: .indigo
                    )
                }
            }
            .padding(14)
            .glassCardBackground(radius: 16)

            HStack(spacing: 10) {
                MetricCard(
                    title: "Cache read",
                    value: UsageFormatters.compactCount(metrics.tokens.cacheRead),
                    subtitle: UsageFormatters.percent(metrics.tokens.cacheRead, of: max(metrics.tokens.total, 1)),
                    systemImage: "tray.and.arrow.down"
                )
                MetricCard(
                    title: "Average",
                    value: UsageFormatters.dollars(fromCents: metrics.averageCentsPerRequest),
                    subtitle: "per request",
                    systemImage: "chart.line.uptrend.xyaxis"
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
                .padding(.horizontal, 2)
            }
        }
    }

    private func cycleText(_ summary: UsageSummarySnapshot) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "\(df.string(from: summary.cycleStart)) – \(df.string(from: summary.cycleEnd))"
    }

    private var tokenSplitSection: some View {
        let t = model.currentMetrics.tokens
        let total = max(t.total, 1)
        return sectionSurface(title: "Token split", systemImage: "circle.hexagongrid.fill", accessory: "View details") {
            TokenSplitBar(tokens: t)
                .accessibilityLabel("Token split: input \(UsageFormatters.percent(t.input, of: total)), output \(UsageFormatters.percent(t.output, of: total)), cache write \(UsageFormatters.percent(t.cacheWrite, of: total)), cache read \(UsageFormatters.percent(t.cacheRead, of: total))")
            HStack(spacing: 18) {
                splitLegend("Input", t.input, total, .blue)
                splitLegend("Output", t.output, total, .cyan)
                splitLegend("Cache", t.cacheWrite + t.cacheRead, total, .gray)
            }
            .font(.caption)
        }
    }

    private func splitLegend(_ label: String, _ value: Int, _ total: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("\(label) \(UsageFormatters.percent(value, of: total))")
                    .foregroundStyle(.primary)
            }
            Text("\(UsageFormatters.compactCount(value)) tokens")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var activitySection: some View {
        let metrics = model.currentMetrics
        return sectionSurface(title: "Activity", systemImage: "bolt.horizontal.circle") {
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                StatTile(
                    systemImage: "waveform.path.ecg",
                    label: "Requests",
                    value: "\(metrics.eventCount)",
                    detail: "Requests",
                    color: .blue
                )
                StatTile(
                    systemImage: "clock",
                    label: "Background",
                    value: "\(metrics.headlessCount)",
                    detail: "Agents",
                    color: .blue
                )
                StatTile(
                    systemImage: "bolt.fill",
                    label: "Avg / request",
                    value: UsageFormatters.dollars(fromCents: metrics.averageCentsPerRequest),
                    detail: "Avg cost",
                    color: .blue
                )
                StatTile(
                    systemImage: "checkmark.circle",
                    label: "Cache reads",
                    value: UsageFormatters.percent(metrics.tokens.cacheRead, of: max(metrics.tokens.total, 1)),
                    detail: "Cache",
                    color: .cyan
                )
            }
        }
    }

    private func busiestDayText(_ day: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM"
        return df.string(from: day)
    }

    private var trendSection: some View {
        sectionSurface(title: "Daily trend", systemImage: "chart.bar.xaxis") {
            HStack {
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
        return sectionSurface(title: "Time of day", systemImage: "clock") {
            if peak == 0 {
                Text("No usage in this range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HourHeatmapView(activity: activity, peak: peak)
            }
        }
    }

    private var modelsSection: some View {
        let sorted = model.sortedModels
        let maxTokens = sorted.first?.tokens.total ?? 1
        let maxCost = sorted.map(\.chargedCents).max() ?? 1
        let maxRequests = sorted.map(\.requestCount).max() ?? 1
        let maxEfficiency = sorted.map(\.centsPerMillionTokens).max() ?? 1

        return sectionSurface(title: "Models", systemImage: "cpu") {
            HStack {
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

    private var bottomAnalyticsGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            hourHeatmapSection
            modelsSection
        }
    }

    private var footer: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("Launch at login", isOn: Binding(
                get: { model.preferences.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .controlSize(.small)
            Button {
                model.showSettings = true
            } label: {
                Label("Settings", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .font(.caption)
        .background(.ultraThinMaterial)
    }

    private func sectionSurface<Content: View>(
        title: String,
        systemImage: String,
        accessory: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if let accessory {
                    Label(accessory, systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground(radius: 16)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
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
        .glassCardBackground(radius: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value). \(subtitle)")
    }
}

struct SummaryChip: View {
    let label: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color)
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value), \(detail)")
    }
}

struct StatTile: View {
    let systemImage: String
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value), \(detail)")
    }
}

struct TokenSplitBar: View {
    let tokens: TokenUsage

    var body: some View {
        let total = max(tokens.total, 1)
        let cache = tokens.cacheWrite + tokens.cacheRead
        GeometryReader { geo in
            HStack(spacing: 0) {
                labeledBarSegment(tokens.input, total, .blue, "Input", width: geo.size.width)
                labeledBarSegment(tokens.output, total, .cyan, "Output", width: geo.size.width)
                labeledBarSegment(cache, total, .gray, "Cache", width: geo.size.width)
            }
        }
        .frame(height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func labeledBarSegment(_ value: Int, _ total: Int, _ color: Color, _ label: String, width: CGFloat) -> some View {
        let segmentWidth = max(width * CGFloat(value) / CGFloat(total), value > 0 ? 20 : 0)
        return ZStack {
            color
            if segmentWidth > 36 {
                Text(UsageFormatters.percent(value, of: total))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: segmentWidth)
        .accessibilityLabel("\(label) \(UsageFormatters.percent(value, of: total))")
    }
}

private extension View {
    func glassCardBackground(radius: CGFloat = 16) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    func glassButtonBackground(radius: CGFloat = 11) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
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
                    .fill(Color.accentColor.opacity(0.45))
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

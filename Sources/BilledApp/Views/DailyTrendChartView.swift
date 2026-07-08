import Charts
import BilledCore
import SwiftUI

struct DailyTrendChartView: View {
    let points: [DailyTrendPoint]
    let metric: AppModel.TrendMetric

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Day", point.day, unit: .day),
                y: .value(yAxisLabel, yValue(for: point))
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(points.count, 7))) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatYAxis(doubleValue))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 130)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var yAxisLabel: String {
        metric == .tokens ? "Tokens" : "Cost"
    }

    private func yValue(for point: DailyTrendPoint) -> Double {
        switch metric {
        case .tokens: Double(point.tokenTotal)
        case .cost: point.chargedCents / 100
        }
    }

    private func formatYAxis(_ value: Double) -> String {
        switch metric {
        case .tokens:
            return UsageFormatters.compactCount(Int(value))
        case .cost:
            return String(format: "$%.0f", value)
        }
    }

    private var accessibilitySummary: String {
        let activeDays = points.filter { $0.eventCount > 0 }
        guard let peak = activeDays.max(by: { yValue(for: $0) < yValue(for: $1) }) else {
            return "Daily trend chart, no usage"
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        switch metric {
        case .tokens:
            return "Daily token trend. Peak \(UsageFormatters.compactCount(peak.tokenTotal)) tokens on \(df.string(from: peak.day))."
        case .cost:
            return "Daily cost trend. Peak \(UsageFormatters.dollars(fromCents: peak.chargedCents)) on \(df.string(from: peak.day))."
        }
    }
}

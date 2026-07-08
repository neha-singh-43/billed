import Foundation

public enum MetricsCalculator {
    public static func metrics(for events: [UsageEvent], in interval: DateInterval) -> UsageMetrics {
        let filtered = events.filter { interval.contains($0.timestamp) }
        var tokens = TokenUsage()
        var charged = 0.0
        var headlessCount = 0
        var byModel: [String: (tokens: TokenUsage, charged: Double, count: Int)] = [:]

        for event in filtered {
            charged += event.chargedCents
            if event.isHeadless { headlessCount += 1 }
            if let t = event.tokens {
                tokens = tokens + t
                var entry = byModel[event.model] ?? (TokenUsage(), 0, 0)
                entry.tokens = entry.tokens + t
                entry.charged += event.chargedCents
                entry.count += 1
                byModel[event.model] = entry
            } else {
                var entry = byModel[event.model] ?? (TokenUsage(), 0, 0)
                entry.charged += event.chargedCents
                entry.count += 1
                byModel[event.model] = entry
            }
        }

        let models = byModel.map { key, value in
            ModelRollup(model: key, tokens: value.tokens, chargedCents: value.charged, requestCount: value.count)
        }
        .sorted { $0.tokens.total > $1.tokens.total }

        return UsageMetrics(
            tokens: tokens,
            chargedCents: charged,
            eventCount: filtered.count,
            headlessCount: headlessCount,
            models: models
        )
    }

    /// The day with the highest token total in the given trend points.
    public static func busiestDay(in points: [DailyTrendPoint]) -> DailyTrendPoint? {
        points.filter { $0.tokenTotal > 0 }.max { $0.tokenTotal < $1.tokenTotal }
    }

    /// Requests and tokens bucketed by local hour of day (0–23), summed across
    /// all days in the interval. Always returns 24 entries.
    public static func hourOfDayActivity(
        for events: [UsageEvent],
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [HourActivity] {
        var requestByHour = [Int](repeating: 0, count: 24)
        var tokensByHour = [Int](repeating: 0, count: 24)

        for event in events where interval.contains(event.timestamp) {
            let hour = calendar.component(.hour, from: event.timestamp)
            guard (0..<24).contains(hour) else { continue }
            requestByHour[hour] += 1
            tokensByHour[hour] += event.tokens?.total ?? 0
        }

        return (0..<24).map { hour in
            HourActivity(hour: hour, requestCount: requestByHour[hour], tokenTotal: tokensByHour[hour])
        }
    }

    public static func tokensToday(from events: [UsageEvent], now: Date = .now) -> Int {
        let start = Calendar.current.startOfDay(for: now)
        return events
            .filter { $0.timestamp >= start }
            .compactMap(\.tokens?.total)
            .reduce(0, +)
    }

    public static func spendToday(from events: [UsageEvent], now: Date = .now) -> Double {
        let start = Calendar.current.startOfDay(for: now)
        return events
            .filter { $0.timestamp >= start }
            .map(\.chargedCents)
            .reduce(0, +)
    }

    public static func spendThisCycle(from events: [UsageEvent], cycleStart: Date?, now: Date = .now) -> Double {
        let start = cycleStart ?? now.addingTimeInterval(-30 * 86_400)
        return events
            .filter { $0.timestamp >= start }
            .map(\.chargedCents)
            .reduce(0, +)
    }

    public static func tokensThisCycle(from events: [UsageEvent], cycleStart: Date?, now: Date = .now) -> Int {
        let start = cycleStart ?? now.addingTimeInterval(-30 * 86_400)
        return events
            .filter { $0.timestamp >= start }
            .compactMap(\.tokens?.total)
            .reduce(0, +)
    }

    public static func projectedCycleSpend(
        chargedSoFar: Double,
        cycleStart: Date,
        cycleEnd: Date,
        now: Date = .now
    ) -> Double {
        let elapsed = max(now.timeIntervalSince(cycleStart), 1)
        let total = max(cycleEnd.timeIntervalSince(cycleStart), 1)
        return chargedSoFar / elapsed * total
    }

    public static func dailyTrend(
        for events: [UsageEvent],
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> [DailyTrendPoint] {
        let filtered = events.filter { interval.contains($0.timestamp) }
        var buckets: [Date: (tokens: TokenUsage, cents: Double, count: Int)] = [:]

        for event in filtered {
            let day = calendar.startOfDay(for: event.timestamp)
            var bucket = buckets[day] ?? (TokenUsage(), 0, 0)
            bucket.cents += event.chargedCents
            bucket.count += 1
            if let t = event.tokens {
                bucket.tokens = bucket.tokens + t
            }
            buckets[day] = bucket
        }

        var points: [DailyTrendPoint] = []
        var day = calendar.startOfDay(for: interval.start)
        let endDay = calendar.startOfDay(for: interval.end)

        while day <= endDay {
            let bucket = buckets[day] ?? (TokenUsage(), 0, 0)
            points.append(
                DailyTrendPoint(
                    day: day,
                    tokenTotal: bucket.tokens.total,
                    chargedCents: bucket.cents,
                    eventCount: bucket.count
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return points
    }
}

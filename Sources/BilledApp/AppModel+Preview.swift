#if DEBUG
import BilledCore
import Foundation

extension AppModel {
    /// Returns a pre-seeded `AppModel` suitable for SwiftUI previews.
    /// Uses the private `init(_preview:)` to avoid triggering the async
    /// bootstrap and leaves state entirely under our control.
    @MainActor
    static func sample() -> AppModel {
        let cal = Calendar.current
        let now = Date()
        let cycleStart = cal.date(byAdding: .day, value: -18, to: now)!
        let cycleEnd   = cal.date(byAdding: .day, value: 12, to: now)!

        let summary = UsageSummarySnapshot(
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
            membershipType: "pro",
            limitType: "individual",
            teamPooledUsed: nil,
            teamPooledLimit: nil,
            teamPooledRemaining: nil,
            onDemandUsed: 420.0,
            individualOverallUsed: 1_250_000
        )

        // Generate 18 days of synthetic events
        var rng = SeededRNG(seed: 42)
        let models: [(String, Double)] = [
            ("claude-3-5-sonnet", 0.8),
            ("gpt-4o",            0.5),
            ("gemini-2.0-flash",  0.3),
            ("o1-preview",        1.2),
        ]

        var events: [UsageEvent] = []
        for dayOffset in 0 ..< 18 {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            let eventCount = Int(rng.next() % 6) + 3
            for _ in 0 ..< eventCount {
                let (modelName, costFactor) = models[Int(rng.next() % UInt64(models.count))]
                let inputTokens  = Int(rng.next() % 40_000) + 5_000
                let outputTokens = Int(rng.next() % 8_000)  + 500
                let cacheRead    = Int(rng.next() % 20_000)
                let tokens = TokenUsage(
                    input: inputTokens,
                    output: outputTokens,
                    cacheWrite: 0,
                    cacheRead: cacheRead
                )
                let chargedCents = Double(inputTokens + outputTokens) / 1_000_000 * 100 * costFactor
                let hourOffset   = TimeInterval(Int(rng.next() % 14) + 8) * 3600
                events.append(UsageEvent(
                    timestamp: day.addingTimeInterval(hourOffset),
                    model: modelName,
                    kind: .usageBased,
                    isTokenBased: true,
                    isHeadless: rng.next() % 4 == 0,
                    tokens: tokens,
                    chargedCents: chargedCents
                ))
            }
        }

        let model = AppModel(_preview: ())
        model.loadState = .loaded(lastUpdated: now)
        model.summary = summary
        model.events = events
        model.menuBarLabel = "1.2M"
        model.selectedProvider = .cursor
        return model
    }
}

/// Tiny deterministic LCG — avoids pulling in GameplayKit just for previews.
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
#endif

import BilledCore
import XCTest

final class BilledCoreTests: XCTestCase {
    func testDecodesEventsFixture() throws {
        let url = Bundle.module.url(forResource: "get-filtered-usage-events.sample", withExtension: "json")!
        let data = try Data(contentsOf: url)
        struct Wrapper: Decodable {
            let totalUsageEventsCount: Int?
            let events: [RawEvent]

            enum CodingKeys: String, CodingKey {
                case totalUsageEventsCount
                case usageEventsDisplay
            }

            struct RawEvent: Decodable {
                let model: String?
                let chargedCents: Double?
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                totalUsageEventsCount = try c.decodeIfPresent(Int.self, forKey: .totalUsageEventsCount)
                events = try c.decode([RawEvent].self, forKey: .usageEventsDisplay)
            }
        }
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        XCTAssertEqual(wrapper.totalUsageEventsCount, 90)
        XCTAssertEqual(wrapper.events.count, 90)
        XCTAssertEqual(wrapper.events.first?.model, "claude-opus-4-8-thinking-high")
    }

    func testMetricsCalculatorRollsUpTokensAndCost() {
        let event = UsageEvent(
            timestamp: Date(),
            model: "composer-2.5",
            kind: .includedInSubscription,
            isTokenBased: true,
            isHeadless: false,
            tokens: TokenUsage(input: 100, output: 50, cacheWrite: 10, cacheRead: 1000),
            chargedCents: 12.5
        )
        let interval = DateInterval(start: Date().addingTimeInterval(-3600), end: Date().addingTimeInterval(3600))
        let metrics = MetricsCalculator.metrics(for: [event], in: interval)
        XCTAssertEqual(metrics.tokens.total, 1160)
        XCTAssertEqual(metrics.chargedCents, 12.5)
        XCTAssertEqual(metrics.models.count, 1)
        XCTAssertEqual(metrics.models[0].model, "composer-2.5")
    }

    func testMetricsCountsHeadlessAndDerivedStats() {
        let now = Date()
        let events = [
            UsageEvent(
                timestamp: now,
                model: "m1",
                kind: .usageBased,
                isTokenBased: true,
                isHeadless: true,
                tokens: TokenUsage(input: 100, output: 0, cacheWrite: 0, cacheRead: 900),
                chargedCents: 20
            ),
            UsageEvent(
                timestamp: now,
                model: "m1",
                kind: .usageBased,
                isTokenBased: true,
                isHeadless: false,
                tokens: TokenUsage(input: 100, output: 0, cacheWrite: 0, cacheRead: 900),
                chargedCents: 40
            ),
        ]
        let interval = DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60))
        let metrics = MetricsCalculator.metrics(for: events, in: interval)
        XCTAssertEqual(metrics.eventCount, 2)
        XCTAssertEqual(metrics.headlessCount, 1)
        XCTAssertEqual(metrics.interactiveCount, 1)
        XCTAssertEqual(metrics.averageCentsPerRequest, 30)
        XCTAssertEqual(metrics.cacheReadShare, 0.9, accuracy: 0.001)
    }

    func testBusiestDayPicksHighestTokenDay() {
        let calendar = Calendar.current
        let day1 = calendar.startOfDay(for: Date())
        let day2 = calendar.date(byAdding: .day, value: -1, to: day1)!
        let points = [
            DailyTrendPoint(day: day2, tokenTotal: 500, chargedCents: 5, eventCount: 1),
            DailyTrendPoint(day: day1, tokenTotal: 1200, chargedCents: 10, eventCount: 2),
        ]
        XCTAssertEqual(MetricsCalculator.busiestDay(in: points)?.day, day1)
        XCTAssertNil(MetricsCalculator.busiestDay(in: []))
    }

    func testHourOfDayActivityBucketsByHour() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let base = cal.startOfDay(for: Date())
        let nineAM = cal.date(byAdding: .hour, value: 9, to: base)!
        let events = [
            UsageEvent(timestamp: nineAM, model: "m", kind: .usageBased, isTokenBased: true,
                       isHeadless: false, tokens: TokenUsage(input: 100), chargedCents: 1),
            UsageEvent(timestamp: nineAM.addingTimeInterval(120), model: "m", kind: .usageBased,
                       isTokenBased: true, isHeadless: false, tokens: TokenUsage(input: 50), chargedCents: 1),
        ]
        let interval = DateInterval(start: base, end: cal.date(byAdding: .day, value: 1, to: base)!)
        let hours = MetricsCalculator.hourOfDayActivity(for: events, in: interval, calendar: cal)
        XCTAssertEqual(hours.count, 24)
        XCTAssertEqual(hours[9].requestCount, 2)
        XCTAssertEqual(hours[9].tokenTotal, 150)
        XCTAssertEqual(hours[10].requestCount, 0)
    }

    func testModelRollupCostEfficiency() {
        let rollup = ModelRollup(
            model: "m",
            tokens: TokenUsage(input: 500_000, output: 500_000),
            chargedCents: 200,
            requestCount: 1
        )
        XCTAssertEqual(rollup.centsPerMillionTokens, 200, accuracy: 0.001)
    }

    func testDecodeJWTClaimsExtractsSub() {
        // header.payload.signature with payload {"sub":"auth0|user_123","exp":2000000000}
        func b64url(_ s: String) -> String {
            Data(s.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let payload = b64url("{\"sub\":\"auth0|user_123\",\"exp\":2000000000}")
        let token = "\(b64url("{\"alg\":\"HS256\"}")).\(payload).sig"
        let claims = LocalAuthReader.decodeJWTClaims(token)
        XCTAssertEqual(claims?["sub"] as? String, "auth0|user_123")
    }

    func testDecodeJWTClaimsRejectsMalformed() {
        XCTAssertNil(LocalAuthReader.decodeJWTClaims("not-a-jwt"))
        XCTAssertNil(LocalAuthReader.decodeJWTClaims("a.b"))
    }

    func testCompactCountFormatting() {
        XCTAssertEqual(UsageFormatters.compactCount(950), "950")
        XCTAssertEqual(UsageFormatters.compactCount(1_500), "1.5K")
        XCTAssertEqual(UsageFormatters.compactCount(2_000_000), "2M")
    }

    func testDailyTrendBucketsByDay() {
        let calendar = Calendar.current
        let day1 = calendar.startOfDay(for: Date())
        let day2 = calendar.date(byAdding: .day, value: -1, to: day1)!
        let events = [
            UsageEvent(
                timestamp: day1.addingTimeInterval(3600),
                model: "m1",
                kind: .usageBased,
                isTokenBased: true,
                isHeadless: false,
                tokens: TokenUsage(input: 100, output: 50),
                chargedCents: 10
            ),
            UsageEvent(
                timestamp: day2.addingTimeInterval(3600),
                model: "m2",
                kind: .usageBased,
                isTokenBased: true,
                isHeadless: false,
                tokens: TokenUsage(input: 200, output: 100),
                chargedCents: 20
            ),
        ]
        let interval = DateInterval(start: day2, end: day1.addingTimeInterval(86_400))
        let trend = MetricsCalculator.dailyTrend(for: events, in: interval, calendar: calendar)
        XCTAssertEqual(trend.count, 2)
        XCTAssertEqual(trend[0].tokenTotal, 300)
        XCTAssertEqual(trend[0].chargedCents, 20)
        XCTAssertEqual(trend[1].tokenTotal, 150)
        XCTAssertEqual(trend[1].chargedCents, 10)
    }
}

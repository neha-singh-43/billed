import Foundation

public enum UsageFormatters {
    public static func compactCount(_ value: Int) -> String {
        let abs = Double(abs(value))
        let sign = value < 0 ? "-" : ""
        switch abs {
        case 1_000_000_000...:
            return sign + String(format: "%.1fB", abs / 1_000_000_000).replacingOccurrences(of: ".0B", with: "B")
        case 1_000_000...:
            return sign + String(format: "%.1fM", abs / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
        case 1_000...:
            return sign + String(format: "%.1fK", abs / 1_000).replacingOccurrences(of: ".0K", with: "K")
        default:
            return sign + String(value)
        }
    }

    public static func dollars(fromCents cents: Double) -> String {
        String(format: "$%.2f", cents / 100)
    }

    public static func percent(_ part: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.0f%%", Double(part) / Double(total) * 100)
    }

    public static func relativeTime(since date: Date, now: Date = .now) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86_400)d ago"
    }
}

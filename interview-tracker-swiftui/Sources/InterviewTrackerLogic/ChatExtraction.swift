import Foundation

/// Lenient date parsing for agent tool arguments.
public enum ISO8601Flexible {
    public static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: string) { return date }

        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = .current
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ] {
            local.dateFormat = format
            if let date = local.date(from: string) { return date }
        }
        return nil
    }

    /// True when the string carries a clock time, not just a calendar day.
    public static func hasClockTime(_ string: String?) -> Bool {
        guard let string else { return false }
        return string.contains(":")
    }
}

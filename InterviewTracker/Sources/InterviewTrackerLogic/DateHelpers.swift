import Foundation

/// Shared Monday–Sunday week bounds (Monday 00:00:00 … Sunday 23:59:59).
public enum WeekBounds {
    public static func mondayToSunday(
        containing date: Date = Date(),
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        let weekday = calendar.component(.weekday, from: date)
        let daysToMonday = (weekday + 5) % 7
        guard let mondayDay = calendar.date(byAdding: .day, value: -daysToMonday, to: date),
              let monday = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: mondayDay),
              let sundayDay = calendar.date(byAdding: .day, value: 6, to: monday),
              let sundayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sundayDay)
        else { return nil }
        return (monday, sundayEnd)
    }
}

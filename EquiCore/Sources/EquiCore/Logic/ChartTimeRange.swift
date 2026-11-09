import Foundation

/// Time ranges of measurement charts, like in Apple Health: T / W / M / 6M / J / Alle (F-MESS-03).
public enum ChartTimeRange: String, CaseIterable, Codable, Sendable, Identifiable {
  case day
  case week
  case month
  case sixMonths
  case year
  case all

  public var id: String { rawValue }

  /// Visible interval ending with the current day, or `nil` for `.all`.
  public func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
    let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
    let start: Date
    switch self {
    case .day: start = calendar.startOfDay(for: now)
    case .week: start = calendar.date(byAdding: .day, value: -7, to: endOfToday)!
    case .month: start = calendar.date(byAdding: .month, value: -1, to: endOfToday)!
    case .sixMonths: start = calendar.date(byAdding: .month, value: -6, to: endOfToday)!
    case .year: start = calendar.date(byAdding: .year, value: -1, to: endOfToday)!
    case .all: return nil
    }
    return DateInterval(start: start, end: endOfToday)
  }

  /// Interval to display for the given timestamps; for `.all` the span of the data (at least one day).
  public func domain(for timestamps: [Date], now: Date = .now, calendar: Calendar = .current) -> DateInterval {
    if let interval = interval(now: now, calendar: calendar) { return interval }
    guard let first = timestamps.min(), let last = timestamps.max() else {
      return ChartTimeRange.day.interval(now: now, calendar: calendar)!
    }
    let start = calendar.startOfDay(for: first)
    let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(last, now)))!
    return DateInterval(start: start, end: end)
  }
}

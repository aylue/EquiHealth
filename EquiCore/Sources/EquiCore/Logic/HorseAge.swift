import Foundation

/// Age of a horse computed from its birth date (F-PFERD-03).
public enum HorseAge {
  /// Full years and remaining months between `birthDate` and `now`; `nil` if born in the future.
  public static func components(
    birthDate: Date, now: Date = .now, calendar: Calendar = .current
  ) -> DateComponents? {
    guard birthDate <= now else { return nil }
    return calendar.dateComponents([.year, .month], from: birthDate, to: now)
  }
}

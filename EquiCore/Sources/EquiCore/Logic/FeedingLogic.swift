import Foundation
import SwiftData

/// One line of a feeding plan as edited in the UI (F-FUTTER-02).
public struct FeedingPlanLine: Equatable, Sendable {
  public var feedID: UUID
  public var amount: Double
  public var unit: FeedUnit
  public var meal: Meal

  public init(feedID: UUID, amount: Double, unit: FeedUnit, meal: Meal) {
    self.feedID = feedID
    self.amount = amount
    self.unit = unit
    self.meal = meal
  }

  public init?(_ item: FeedingPlanItem) {
    guard let feed = item.feed else { return nil }
    self.init(feedID: feed.id, amount: item.amount, unit: item.unit, meal: item.meal)
  }
}

/// Daily amount of one feed category in kilograms (F-FUTTER-06).
public struct DailyFeedTotal: Equatable, Sendable {
  public let day: Date
  public let category: FeedCategory
  public let kilograms: Double
}

extension FeedUnit {
  /// Factor to kilograms for mass units; `nil` for units that cannot be converted
  /// (liter, scoop, flake – Q-004).
  public var kilogramsPerUnit: Double? {
    switch self {
    case .kilogram: 1
    case .gram: 0.001
    case .liter, .scoop, .flake: nil
    }
  }
}

extension Meal {
  /// Display order of meals.
  public var sortOrder: Int {
    switch self {
    case .morning: 0
    case .noon: 1
    case .evening: 2
    case .adLibitum: 3
    }
  }
}

extension FeedingPlanItem {
  /// Whether the item is valid at `date` (`validFrom` inclusive, `validUntil` exclusive).
  public func isValid(at date: Date) -> Bool {
    validFrom <= date && (validUntil.map { date < $0 } ?? true)
  }
}

extension Horse {
  /// Plan items valid at `date`, ordered by meal and feed name (F-FUTTER-03, F-FUTTER-05).
  public func feedingPlan(at date: Date) -> [FeedingPlanItem] {
    (feedingPlanItems ?? [])
      .filter { $0.isValid(at: date) }
      .sorted {
        ($0.meal.sortOrder, $0.feed?.name ?? "") < ($1.meal.sortOrder, $1.feed?.name ?? "")
      }
  }

  /// Deviating or additional feedings on the calendar day of `day` (F-FUTTER-04, F-FUTTER-05).
  public func feedingLogs(onDayOf day: Date, calendar: Calendar = .current) -> [FeedingLog] {
    (feedingLogs ?? [])
      .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
      .sorted { $0.timestamp < $1.timestamp }
  }

  /// Start dates of all plan versions, newest first (F-FUTTER-03).
  public var feedingPlanVersionDates: [Date] {
    Array(Set((feedingPlanItems ?? []).map(\.validFrom))).sorted(by: >)
  }

  /// Makes `lines` the plan valid from the start of `date` (F-FUTTER-03).
  ///
  /// Items valid at that moment that are unchanged stay as they are. Changed or removed items end
  /// at `date`; new or changed lines become new items starting at `date`. Items that started on the
  /// same day are replaced instead of ended, so no zero-length versions remain.
  // ANNAHME: Planänderungen gelten ab Tagesbeginn. Bereits geplante künftige Versionen
  // (Beginn nach dem Änderungsdatum) bleiben unberührt. Siehe OPEN_QUESTIONS.md (Q-032).
  public func applyFeedingPlan(
    _ lines: [FeedingPlanLine], from date: Date, feeds: [Feed], in context: ModelContext,
    calendar: Calendar = .current
  ) {
    let start = calendar.startOfDay(for: date)
    var remaining = lines
    for item in feedingPlan(at: start) {
      if let line = FeedingPlanLine(item), let index = remaining.firstIndex(of: line) {
        remaining.remove(at: index)
        continue
      }
      if item.validFrom >= start {
        context.delete(item)
      } else {
        item.validUntil = start
        item.touch()
      }
    }
    for line in remaining {
      guard let feed = feeds.first(where: { $0.id == line.feedID }) else { continue }
      let item = FeedingPlanItem(
        horse: self, feed: feed, amount: line.amount, unit: line.unit, meal: line.meal, validFrom: start)
      context.insert(item)
    }
    touch()
  }

  /// Daily kilograms per feed category from plan and additional feedings (F-FUTTER-06).
  /// Amounts in units that cannot be converted to kilograms are left out (Q-004).
  public func dailyFeedTotals(
    from startDate: Date, through endDate: Date, calendar: Calendar = .current
  ) -> [DailyFeedTotal] {
    var totals: [DailyFeedTotal] = []
    var day = calendar.startOfDay(for: startDate)
    let last = calendar.startOfDay(for: endDate)
    while day <= last {
      var perCategory: [FeedCategory: Double] = [:]
      for item in feedingPlan(at: day) {
        guard let factor = item.unit.kilogramsPerUnit, let feed = item.feed else { continue }
        perCategory[feed.category, default: 0] += item.amount * factor
      }
      for log in feedingLogs(onDayOf: day, calendar: calendar) {
        guard let factor = log.unit.kilogramsPerUnit, let feed = log.feed else { continue }
        perCategory[feed.category, default: 0] += log.amount * factor
      }
      for category in FeedCategory.allCases {
        if let kilograms = perCategory[category], kilograms > 0 {
          totals.append(DailyFeedTotal(day: day, category: category, kilograms: kilograms))
        }
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
      day = next
    }
    return totals
  }
}

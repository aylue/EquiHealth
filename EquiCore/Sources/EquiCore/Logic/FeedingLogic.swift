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

/// A plan position on one day with its deviation, if any (F-FUTTER-05, Q-033).
public struct FeedingDayEntry: Identifiable {
  public let planItem: FeedingPlanItem
  /// Replacement or omission recorded for this position on that day.
  public let deviation: FeedingLog?

  public var id: UUID { planItem.id }

  public var isOmitted: Bool { deviation?.kind == .omission }

  /// Amount actually fed: the plan amount, the replacement amount, or 0 when left out.
  public var effectiveAmount: Double {
    guard let deviation else { return planItem.amount }
    return deviation.kind == .omission ? 0 : deviation.amount
  }

  public var effectiveUnit: FeedUnit {
    deviation.map { $0.kind == .omission ? planItem.unit : $0.unit } ?? planItem.unit
  }
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

  /// Additional feedings on the calendar day of `day` (kind `.extra`, F-FUTTER-04).
  public func extraFeedingLogs(onDayOf day: Date, calendar: Calendar = .current) -> [FeedingLog] {
    feedingLogs(onDayOf: day, calendar: calendar).filter { $0.kind == .extra }
  }

  /// Plan positions of the calendar day of `day` with their deviations (F-FUTTER-05, Q-033).
  /// The plan valid at noon of that day is used.
  public func feedingDay(_ day: Date, calendar: Calendar = .current) -> [FeedingDayEntry] {
    let start = calendar.startOfDay(for: day)
    let noon = calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    let deviations = feedingLogs(onDayOf: day, calendar: calendar).filter { $0.kind != .extra }
    return feedingPlan(at: noon).map { item in
      let match =
        deviations
        .filter { $0.feed?.id == item.feed?.id && $0.mealRaw == item.mealRaw }
        .max { $0.updatedAt < $1.updatedAt }
      return FeedingDayEntry(planItem: item, deviation: match)
    }
  }

  /// Records that `item` was fed with `amount` (`nil` = left out) on the day of `day` (Q-033).
  /// Replaces an earlier deviation of the same position on that day.
  public func setFeedingDeviation(
    for item: FeedingPlanItem, on day: Date, amount: Double?, unit: FeedUnit, in context: ModelContext,
    calendar: Calendar = .current
  ) {
    clearFeedingDeviation(for: item, on: day, in: context, calendar: calendar)
    let start = calendar.startOfDay(for: day)
    let noon = calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    let log = FeedingLog(horse: self, feed: item.feed, amount: amount ?? 0, unit: unit, timestamp: noon)
    log.kind = amount == nil ? .omission : .replacement
    log.meal = item.meal
    context.insert(log)
    touch()
  }

  /// Removes every deviation of `item` on the day of `day`, so the plan applies again (Q-033).
  public func clearFeedingDeviation(
    for item: FeedingPlanItem, on day: Date, in context: ModelContext, calendar: Calendar = .current
  ) {
    for log in feedingLogs(onDayOf: day, calendar: calendar)
    where log.kind != .extra && log.feed?.id == item.feed?.id && log.mealRaw == item.mealRaw {
      context.delete(log)
    }
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

  /// Daily kilograms per feed category from the plan (with that day's deviations) and additional
  /// feedings (F-FUTTER-06, Q-033).
  /// Amounts in units that cannot be converted to kilograms are left out (Q-004).
  public func dailyFeedTotals(
    from startDate: Date, through endDate: Date, calendar: Calendar = .current
  ) -> [DailyFeedTotal] {
    var totals: [DailyFeedTotal] = []
    var day = calendar.startOfDay(for: startDate)
    let last = calendar.startOfDay(for: endDate)
    while day <= last {
      var perCategory: [FeedCategory: Double] = [:]
      for entry in feedingDay(day, calendar: calendar) {
        guard let factor = entry.effectiveUnit.kilogramsPerUnit, let feed = entry.planItem.feed else { continue }
        perCategory[feed.category, default: 0] += entry.effectiveAmount * factor
      }
      for log in extraFeedingLogs(onDayOf: day, calendar: calendar) {
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

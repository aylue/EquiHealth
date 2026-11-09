import Foundation

extension IntervalUnit {
  /// Adds `value` units to `date`.
  public func add(_ value: Int, to date: Date, calendar: Calendar = .current) -> Date? {
    switch self {
    case .days: calendar.date(byAdding: .day, value: value, to: date)
    case .weeks: calendar.date(byAdding: .day, value: 7 * value, to: date)
    case .months: calendar.date(byAdding: .month, value: value, to: date)
    case .years: calendar.date(byAdding: .year, value: value, to: date)
    }
  }
}

extension ReminderKind {
  /// Treatment kind and vaccination target a rule of this kind is fulfilled by.
  public var defaultMatching: (kind: TreatmentKind, target: VaccinationTarget?)? {
    switch self {
    case .vaccinationInfluenza: (.vaccination, .influenza)
    case .vaccinationTetanus: (.vaccination, .tetanus)
    case .vaccinationHerpes: (.vaccination, .herpes)
    case .dentalCheck: (.dental, nil)
    case .farrier: (.farrier, nil)
    case .deworming: (.deworming, nil)
    case .custom: nil
    }
  }
}

extension ReminderRule {
  public var matchingTreatmentKind: TreatmentKind? {
    get { matchingTreatmentKindRaw.flatMap(TreatmentKind.init(rawValue:)) }
    set { matchingTreatmentKindRaw = newValue?.rawValue }
  }

  public var matchingVaccinationTarget: VaccinationTarget? {
    get { matchingVaccinationTargetRaw.flatMap(VaccinationTarget.init(rawValue:)) }
    set { matchingVaccinationTargetRaw = newValue?.rawValue }
  }

  /// Whether `treatment` fulfils this rule: same treatment kind and, for vaccinations with a
  /// target, a vaccine against that disease (F-ERIN-01, F-BEH-06).
  public func isFulfilled(by treatment: Treatment) -> Bool {
    guard let kind = matchingTreatmentKind, treatment.kind == kind else { return false }
    guard let target = matchingVaccinationTarget else { return true }
    return (treatment.medications ?? []).contains { $0.vaccinationTargets.contains(target) }
  }

  /// Date of the most recent fulfilling treatment of the rule's horse.
  public var lastFulfilledDate: Date? {
    (horse?.treatments ?? []).filter(isFulfilled(by:)).map(\.date).max()
  }

  /// Next due day (start of day): last fulfilling treatment + interval, otherwise `startDate`
  /// (SPEC section 3, "Fälligkeit einer Erinnerung").
  public func nextDueDate(calendar: Calendar = .current) -> Date? {
    if let last = lastFulfilledDate {
      return intervalUnit.add(max(intervalValue, 1), to: calendar.startOfDay(for: last), calendar: calendar)
    }
    return startDate.map { calendar.startOfDay(for: $0) }
  }

  /// `day` at the rule's reminder time.
  public func reminderTime(on day: Date, calendar: Calendar = .current) -> Date? {
    calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: day)
  }
}

/// Kind of a planned local notification.
public enum PlannedNotificationKind: String, Sendable {
  /// Early reminder `leadTimeDays` before the due date (F-ERIN-02).
  case leadTime
  /// Reminder on the due date (F-ERIN-02).
  case due
  /// Postponed reminder after "In 1 Woche erinnern" (F-ERIN-06).
  case snoozed
  /// Competition withdrawal has ended (F-BEH-11).
  case competitionWithdrawalEnded
}

/// A local notification to schedule; the app turns it into a `UNNotificationRequest`.
public struct PlannedNotification: Equatable, Sendable {
  public let identifier: String
  public let fireDate: Date
  public let kind: PlannedNotificationKind
  /// `ReminderRule.id` or `Medication.id`.
  public let sourceID: UUID
  public let horseID: UUID?
  /// Due date for reminders, end date for withdrawals.
  public let referenceDate: Date
}

/// Plans local notifications. iOS keeps at most 64 pending notifications per app, so only the
/// next ones are planned and the plan is rebuilt regularly (F-ERIN-05).
public enum ReminderPlanner {
  public static let systemLimit = 64
  public static let identifierPrefix = "equihealth."

  /// - Parameters:
  ///   - rules: candidate rules; inactive rules and rules of archived horses are skipped.
  ///   - medications: medications whose competition withdrawal end should be announced (F-BEH-11).
  public static func plan(
    rules: [ReminderRule], medications: [Medication] = [], now: Date = .now, limit: Int = systemLimit,
    calendar: Calendar = .current
  ) -> [PlannedNotification] {
    var planned: [PlannedNotification] = []
    for rule in rules where rule.isActive && rule.horse?.isArchived != true {
      guard let due = rule.nextDueDate(calendar: calendar) else { continue }
      let horseID = rule.horse?.id
      if let snoozedUntil = rule.snoozedUntil, snoozedUntil > now {
        planned.append(
          PlannedNotification(
            identifier: "\(identifierPrefix)rule.\(rule.id.uuidString).snoozed", fireDate: snoozedUntil,
            kind: .snoozed, sourceID: rule.id, horseID: horseID, referenceDate: due))
        continue
      }
      if rule.leadTimeDays > 0,
        let leadDay = calendar.date(byAdding: .day, value: -rule.leadTimeDays, to: due),
        let leadTime = rule.reminderTime(on: leadDay, calendar: calendar), leadTime > now
      {
        planned.append(
          PlannedNotification(
            identifier: "\(identifierPrefix)rule.\(rule.id.uuidString).lead", fireDate: leadTime, kind: .leadTime,
            sourceID: rule.id, horseID: horseID, referenceDate: due))
      }
      if let dueTime = rule.reminderTime(on: due, calendar: calendar), dueTime > now {
        planned.append(
          PlannedNotification(
            identifier: "\(identifierPrefix)rule.\(rule.id.uuidString).due", fireDate: dueTime, kind: .due,
            sourceID: rule.id, horseID: horseID, referenceDate: due))
      }
    }
    for medication in medications {
      guard let horse = medication.treatment?.horse, !horse.isArchived,
        let end = medication.withdrawalEnd(.competition, calendar: calendar),
        let dayAfter = calendar.date(byAdding: .day, value: 1, to: end),
        let fireDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayAfter), fireDate > now
      else { continue }
      planned.append(
        PlannedNotification(
          identifier: "\(identifierPrefix)withdrawal.\(medication.id.uuidString)", fireDate: fireDate,
          kind: .competitionWithdrawalEnded, sourceID: medication.id, horseID: horse.id, referenceDate: end))
    }
    return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
  }
}

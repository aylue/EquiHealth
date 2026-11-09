import Foundation

/// Kind of a withdrawal period (F-BEH-08).
public enum WithdrawalKind: String, CaseIterable, Sendable {
  /// "Wartezeit Lebensmittel"
  case food
  /// "Karenzzeit Turnier"
  case competition
}

/// Computes withdrawal end dates from user input (F-BEH-08). The app never supplies own values.
///
// ANNAHME: Das Enddatum ist der Tag der letzten Gabe plus n Kalendertage. Die Zeit gilt bis
// einschließlich dieses Tages als laufend. Siehe OPEN_QUESTIONS.md (Q-024).
public enum WithdrawalCalculator {
  /// End date (start of day): `until` if given, else `lastDose + days`.
  public static func endDate(
    until: Date?, days: Int?, lastDose: Date?, calendar: Calendar = .current
  ) -> Date? {
    if let until { return calendar.startOfDay(for: until) }
    guard let days, days >= 0, let lastDose else { return nil }
    return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: lastDose))
  }

  /// Whether a period ending on `end` is still running on `date`.
  public static func isRunning(end: Date, on date: Date = .now, calendar: Calendar = .current) -> Bool {
    calendar.startOfDay(for: date) <= calendar.startOfDay(for: end)
  }
}

extension Medication {
  /// Date of the last dose: end of the medication period, else its start, else the treatment date.
  public var lastDoseDate: Date? {
    endDate ?? startDate ?? treatment?.date
  }

  /// End of the withdrawal period of `kind`, or `nil` if none was entered.
  public func withdrawalEnd(_ kind: WithdrawalKind, calendar: Calendar = .current) -> Date? {
    switch kind {
    case .food:
      WithdrawalCalculator.endDate(
        until: foodWithdrawalUntil, days: foodWithdrawalDays, lastDose: lastDoseDate, calendar: calendar)
    case .competition:
      WithdrawalCalculator.endDate(
        until: competitionWithdrawalUntil, days: competitionWithdrawalDays, lastDose: lastDoseDate,
        calendar: calendar)
    }
  }
}

/// A withdrawal period that is still running (F-BEH-09).
public struct ActiveWithdrawal: Identifiable {
  public let medication: Medication
  public let kind: WithdrawalKind
  public let endDate: Date

  public var id: String { "\(medication.id.uuidString).\(kind.rawValue)" }
}

/// Kinds of entries in the health timeline (F-GESUND-06).
public enum TimelineKind: String, CaseIterable, Sendable {
  case symptom
  case condition
  case treatment
}

/// One entry of the health timeline (F-GESUND-06).
public enum TimelineItem: Identifiable {
  case symptom(SymptomEntry)
  case condition(Condition)
  case treatment(Treatment)

  public var id: UUID {
    switch self {
    case .symptom(let symptom): symptom.id
    case .condition(let condition): condition.id
    case .treatment(let treatment): treatment.id
    }
  }

  public var kind: TimelineKind {
    switch self {
    case .symptom: .symptom
    case .condition: .condition
    case .treatment: .treatment
    }
  }

  /// Date the entry is sorted by: symptom start, diagnosis date (else creation), treatment date.
  public var date: Date {
    switch self {
    case .symptom(let symptom): symptom.startDate
    case .condition(let condition): condition.diagnosedAt ?? condition.createdAt
    case .treatment(let treatment): treatment.date
    }
  }
}

extension Horse {
  /// Symptoms without end date, newest first (F-GESUND-03).
  public var ongoingSymptoms: [SymptomEntry] {
    (symptoms ?? []).filter(\.isOngoing).sorted { $0.startDate > $1.startDate }
  }

  /// Chronic conditions that are not healed (F-GESUND-04).
  public var chronicConditions: [Condition] {
    (conditions ?? []).filter { $0.isChronic && $0.healedAt == nil }.sorted { $0.name < $1.name }
  }

  /// Withdrawal periods still running on `date`, soonest end first (F-BEH-09).
  public func activeWithdrawals(on date: Date = .now, calendar: Calendar = .current) -> [ActiveWithdrawal] {
    let medications = (treatments ?? []).flatMap { $0.medications ?? [] }
    return
      medications
      .flatMap { medication in
        WithdrawalKind.allCases.compactMap { kind -> ActiveWithdrawal? in
          guard let end = medication.withdrawalEnd(kind, calendar: calendar),
            WithdrawalCalculator.isRunning(end: end, on: date, calendar: calendar)
          else { return nil }
          return ActiveWithdrawal(medication: medication, kind: kind, endDate: end)
        }
      }
      .sorted { $0.endDate < $1.endDate }
  }

  /// Timeline of symptoms, conditions and treatments, newest first (F-GESUND-06).
  public func timeline(kinds: Set<TimelineKind> = Set(TimelineKind.allCases)) -> [TimelineItem] {
    var items: [TimelineItem] = []
    if kinds.contains(.symptom) { items += (symptoms ?? []).map(TimelineItem.symptom) }
    if kinds.contains(.condition) { items += (conditions ?? []).map(TimelineItem.condition) }
    if kinds.contains(.treatment) { items += (treatments ?? []).map(TimelineItem.treatment) }
    return items.sorted { $0.date > $1.date }
  }

  /// Most recent vaccination date per disease (F-BEH-04).
  public func lastVaccinations() -> [VaccinationTarget: Date] {
    var result: [VaccinationTarget: Date] = [:]
    for treatment in treatments ?? [] where treatment.kind == .vaccination {
      for target in (treatment.medications ?? []).flatMap(\.vaccinationTargets) {
        if result[target].map({ treatment.date > $0 }) ?? true {
          result[target] = treatment.date
        }
      }
    }
    return result
  }
}

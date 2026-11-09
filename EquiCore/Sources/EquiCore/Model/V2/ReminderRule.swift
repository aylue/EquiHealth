import Foundation
import SwiftData

extension EquiSchemaV2 {
  /// A recurring due date (F-ERIN-01, F-ERIN-02). Next due = last matching treatment + interval,
  /// otherwise `startDate` (SPEC section 3).
  @Model
  public final class ReminderRule: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var kindRaw: String = ReminderKind.custom.rawValue
    public var title: String = ""
    public var intervalValue: Int = 1
    public var intervalUnitRaw: String = IntervalUnit.months.rawValue
    /// Days before the due date for the early reminder (F-ERIN-02).
    public var leadTimeDays: Int = 0
    public var reminderHour: Int = 9
    public var reminderMinute: Int = 0
    public var isActive: Bool = true
    /// Due date used while no matching treatment exists.
    public var startDate: Date?
    /// Set by the notification action "In 1 Woche erinnern" (F-ERIN-06).
    public var snoozedUntil: Date?
    /// `TreatmentKind` raw value of treatments that fulfil this rule.
    public var matchingTreatmentKindRaw: String?
    /// For vaccinations: `VaccinationTarget` raw value the treatment must cover.
    public var matchingVaccinationTargetRaw: String?

    public var horse: Horse?

    public var kind: ReminderKind {
      get { ReminderKind(rawValue: kindRaw) ?? .custom }
      set { kindRaw = newValue.rawValue }
    }

    public var intervalUnit: IntervalUnit {
      get { IntervalUnit(rawValue: intervalUnitRaw) ?? .months }
      set { intervalUnitRaw = newValue.rawValue }
    }

    public init(
      horse: Horse?, kind: ReminderKind, title: String, intervalValue: Int, intervalUnit: IntervalUnit
    ) {
      self.horse = horse
      self.kindRaw = kind.rawValue
      self.title = title
      self.intervalValue = intervalValue
      self.intervalUnitRaw = intervalUnit.rawValue
    }
  }
}

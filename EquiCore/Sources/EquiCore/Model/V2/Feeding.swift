import Foundation
import SwiftData

extension EquiSchemaV2 {
  /// Feed master data shared by all horses (F-FUTTER-01).
  @Model
  public final class Feed: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var name: String = ""
    public var categoryRaw: String = FeedCategory.other.rawValue
    public var manufacturer: String?
    public var defaultUnitRaw: String?
    public var isArchived: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \FeedingPlanItem.feed)
    public var planItems: [FeedingPlanItem]? = []
    @Relationship(deleteRule: .nullify, inverse: \FeedingLog.feed)
    public var logs: [FeedingLog]? = []

    public var category: FeedCategory {
      get { FeedCategory(rawValue: categoryRaw) ?? .other }
      set { categoryRaw = newValue.rawValue }
    }

    public var defaultUnit: FeedUnit? {
      get { defaultUnitRaw.flatMap(FeedUnit.init(rawValue:)) }
      set { defaultUnitRaw = newValue?.rawValue }
    }

    public init(name: String, category: FeedCategory, defaultUnit: FeedUnit? = nil) {
      self.name = name
      self.categoryRaw = category.rawValue
      self.defaultUnitRaw = defaultUnit?.rawValue
    }
  }

  /// A regular ration with a validity period. Changing the plan ends the old item and
  /// starts a new one (F-FUTTER-02, F-FUTTER-03).
  @Model
  public final class FeedingPlanItem: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var amount: Double = 0
    public var unitRaw: String = FeedUnit.kilogram.rawValue
    public var mealRaw: String = Meal.morning.rawValue
    public var validFrom: Date = Date()
    /// `nil` = still valid.
    public var validUntil: Date?

    public var horse: Horse?
    public var feed: Feed?

    public var unit: FeedUnit {
      get { FeedUnit(rawValue: unitRaw) ?? .kilogram }
      set { unitRaw = newValue.rawValue }
    }

    public var meal: Meal {
      get { Meal(rawValue: mealRaw) ?? .morning }
      set { mealRaw = newValue.rawValue }
    }

    public init(
      horse: Horse?, feed: Feed?, amount: Double, unit: FeedUnit, meal: Meal, validFrom: Date
    ) {
      self.horse = horse
      self.feed = feed
      self.amount = amount
      self.unitRaw = unit.rawValue
      self.mealRaw = meal.rawValue
      self.validFrom = validFrom
    }
  }

  /// A deviating or one-off feeding (F-FUTTER-04).
  @Model
  public final class FeedingLog: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var amount: Double = 0
    public var unitRaw: String = FeedUnit.kilogram.rawValue
    public var timestamp: Date = Date()
    public var note: String = ""

    public var horse: Horse?
    public var feed: Feed?

    public var unit: FeedUnit {
      get { FeedUnit(rawValue: unitRaw) ?? .kilogram }
      set { unitRaw = newValue.rawValue }
    }

    public init(horse: Horse?, feed: Feed?, amount: Double, unit: FeedUnit, timestamp: Date = .now) {
      self.horse = horse
      self.feed = feed
      self.amount = amount
      self.unitRaw = unit.rawValue
      self.timestamp = timestamp
    }
  }
}

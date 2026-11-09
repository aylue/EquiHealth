// FROZEN: schema version 2.0.0. Never change this file; it is needed to migrate old stores (EquiMigrationPlan).
import Foundation
import SwiftData

extension EquiSchemaV2 {
  /// A managed horse. Root of all horse-related records (F-TEIL-01); deleting it deletes them (F-PFERD-01).
  @Model
  public final class Horse: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var name: String = ""
    public var callName: String?
    public var birthDate: Date?
    public var breed: String?
    public var sexRaw: String?
    public var color: String?
    public var markings: String?
    /// Universal Equine Life Number.
    public var ueln: String?
    public var microchipNumber: String?
    /// Equine passport status "Schlachttier" (F-BEH-10). `nil` = not specified.
    public var isFoodProducingAnimal: Bool?
    @Attribute(.externalStorage) public var photoData: Data?
    public var notes: String = ""
    public var isArchived: Bool = false
    public var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \StableAssignment.horse)
    public var stableAssignments: [StableAssignment]? = []
    @Relationship(deleteRule: .cascade, inverse: \BodyMeasurement.horse)
    public var measurements: [BodyMeasurement]? = []
    @Relationship(deleteRule: .cascade, inverse: \FeedingPlanItem.horse)
    public var feedingPlanItems: [FeedingPlanItem]? = []
    @Relationship(deleteRule: .cascade, inverse: \FeedingLog.horse)
    public var feedingLogs: [FeedingLog]? = []
    @Relationship(deleteRule: .cascade, inverse: \SymptomEntry.horse)
    public var symptoms: [SymptomEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \Condition.horse)
    public var conditions: [Condition]? = []
    @Relationship(deleteRule: .cascade, inverse: \Treatment.horse)
    public var treatments: [Treatment]? = []
    @Relationship(deleteRule: .cascade, inverse: \ReminderRule.horse)
    public var reminderRules: [ReminderRule]? = []
    @Relationship(deleteRule: .cascade, inverse: \Attachment.horse)
    public var attachments: [Attachment]? = []
    @Relationship(deleteRule: .cascade, inverse: \TrainingSession.horse)
    public var trainingSessions: [TrainingSession]? = []
    /// Added in schema V2 (Q-015).
    @Relationship(deleteRule: .cascade, inverse: \ReferenceRangeSetting.horse)
    public var referenceRanges: [ReferenceRangeSetting]? = []

    public var sex: HorseSex? {
      get { sexRaw.flatMap(HorseSex.init(rawValue:)) }
      set { sexRaw = newValue?.rawValue }
    }

    public init(name: String, sortIndex: Int = 0) {
      self.name = name
      self.sortIndex = sortIndex
    }
  }
}

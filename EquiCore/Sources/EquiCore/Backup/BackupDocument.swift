import Foundation

/// JSON part of an `.equibackup` package (F-BACKUP-01, F-BACKUP-02). Documented in `BACKUP_FORMAT.md`.
///
/// Compatibility rule: fields and arrays added in later schema versions are optional, so backups of
/// older versions keep decoding (F-BACKUP-04). Never rename or remove a field.
public struct BackupDocument: Codable, Equatable, Sendable {
  /// Schema version written by this build (= `CurrentSchema.versionIdentifier.major`).
  public static let currentSchemaVersion = 3

  public var schemaVersion: Int
  public var appVersion: String
  public var exportedAt: Date

  public var horses: [HorseRecord] = []
  public var stables: [StableRecord] = []
  public var stableAssignments: [StableAssignmentRecord] = []
  public var measurements: [MeasurementRecord] = []
  /// Since schema version 2.
  public var referenceRanges: [ReferenceRangeRecord]?
  public var feeds: [FeedRecord] = []
  public var feedingPlanItems: [FeedingPlanItemRecord] = []
  public var feedingLogs: [FeedingLogRecord] = []
  public var symptoms: [SymptomRecord] = []
  public var conditions: [ConditionRecord] = []
  public var treatments: [TreatmentRecord] = []
  public var medications: [MedicationRecord] = []
  public var contacts: [ContactRecord] = []
  public var reminderRules: [ReminderRuleRecord] = []
  public var attachments: [AttachmentRecord] = []
  public var trainingSessions: [TrainingSessionRecord] = []

  public init(schemaVersion: Int = currentSchemaVersion, appVersion: String, exportedAt: Date) {
    self.schemaVersion = schemaVersion
    self.appVersion = appVersion
    self.exportedAt = exportedAt
  }

  /// Number of records per entity, for the restore preview (F-BACKUP-03).
  public var recordCount: Int {
    horses.count + stables.count + stableAssignments.count + measurements.count + (referenceRanges?.count ?? 0)
      + feeds.count + feedingPlanItems.count + feedingLogs.count + symptoms.count + conditions.count
      + treatments.count + medications.count + contacts.count + reminderRules.count + attachments.count
      + trainingSessions.count
  }
}

/// Bookkeeping fields shared by all records.
public struct RecordMeta: Codable, Equatable, Sendable {
  public var id: UUID
  public var createdAt: Date
  public var updatedAt: Date
  public var createdBy: String?
  public var lastModifiedBy: String?
}

public struct HorseRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var name: String
  public var callName: String?
  public var birthDate: Date?
  public var breed: String?
  public var sexRaw: String?
  public var color: String?
  public var markings: String?
  public var ueln: String?
  public var microchipNumber: String?
  public var isFoodProducingAnimal: Bool?
  /// Path of the photo inside the package, e.g. `photos/<id>.jpg`.
  public var photoFile: String?
  public var notes: String
  public var isArchived: Bool
  public var sortIndex: Int
}

public struct StableRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var name: String
  public var locality: String?
  public var latitude: Double?
  public var longitude: Double?
}

public struct StableAssignmentRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var stableID: UUID?
  public var validFrom: Date
  public var validUntil: Date?
}

public struct MeasurementRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var typeRaw: String
  public var value: Double
  public var timestamp: Date
  public var methodRaw: String?
  public var note: String
}

public struct ReferenceRangeRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var measurementTypeRaw: String
  public var lower: Double
  public var upper: Double
}

public struct FeedRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var name: String
  public var categoryRaw: String
  public var manufacturer: String?
  public var defaultUnitRaw: String?
  public var isArchived: Bool
}

public struct FeedingPlanItemRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var feedID: UUID?
  public var amount: Double
  public var unitRaw: String
  public var mealRaw: String
  public var validFrom: Date
  public var validUntil: Date?
}

public struct FeedingLogRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var feedID: UUID?
  public var amount: Double
  public var unitRaw: String
  public var timestamp: Date
  public var note: String
  /// Since schema version 3; `nil` in older backups means `extra`.
  public var kindRaw: String?
  /// Since schema version 3.
  public var mealRaw: String?
}

public struct SymptomRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var conditionID: UUID?
  public var treatmentID: UUID?
  public var categoryRaw: String
  public var customCategoryName: String?
  public var severityRaw: String
  public var startDate: Date
  public var endDate: Date?
  /// `SymptomDetails` as JSON (Base64 in the backup JSON).
  public var detailsData: Data?
  public var note: String
}

public struct ConditionRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var name: String
  public var diagnosedAt: Date?
  public var healedAt: Date?
  public var isChronic: Bool
  public var diagnosedBy: String?
  public var note: String
}

public struct TreatmentRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var contactID: UUID?
  public var conditionID: UUID?
  public var kindRaw: String
  public var customKindName: String?
  public var date: Date
  public var descriptionText: String
  public var cost: Double?
  public var currencyCode: String?
}

public struct MedicationRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var treatmentID: UUID?
  public var productName: String
  public var activeIngredient: String?
  public var dose: Double?
  public var doseUnit: String?
  public var routeRaw: String?
  public var startDate: Date?
  public var endDate: Date?
  public var frequency: String?
  public var batchNumber: String?
  public var foodWithdrawalUntil: Date?
  public var foodWithdrawalDays: Int?
  public var competitionWithdrawalUntil: Date?
  public var competitionWithdrawalDays: Int?
  public var vaccinationTargetsRaw: [String]
  public var customVaccinationTarget: String?
}

public struct ContactRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var name: String
  public var roleRaw: String
  public var practice: String?
  public var phone: String?
  public var email: String?
  public var address: String?
}

public struct ReminderRuleRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var kindRaw: String
  public var title: String
  public var intervalValue: Int
  public var intervalUnitRaw: String
  public var leadTimeDays: Int
  public var reminderHour: Int
  public var reminderMinute: Int
  public var isActive: Bool
  public var startDate: Date?
  public var snoozedUntil: Date?
  public var matchingTreatmentKindRaw: String?
  public var matchingVaccinationTargetRaw: String?
}

public struct AttachmentRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var symptomID: UUID?
  public var treatmentID: UUID?
  public var contentType: String
  public var title: String
  public var fileName: String?
  /// Path of the content inside the package, e.g. `attachments/<id>.jpg`.
  public var file: String?
}

public struct TrainingSessionRecord: Codable, Equatable, Sendable {
  public var meta: RecordMeta
  public var horseID: UUID?
  public var interfaceVersion: Int
  public var typeRaw: String
  public var start: Date
  public var end: Date?
  public var duration: Double
  public var distance: Double?
  public var walkDuration: Double?
  public var trotDuration: Double?
  public var canterDuration: Double?
  public var heartRateAverage: Double?
  public var heartRateMax: Double?
  /// Path of the route JSON inside the package, e.g. `routes/<id>.json`.
  public var routeFile: String?
  public var sourceApp: String?
  public var note: String
}

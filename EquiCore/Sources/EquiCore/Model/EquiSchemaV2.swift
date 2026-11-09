import Foundation
import SwiftData

/// Schema version 2 – the current data model.
///
/// Additive change against V1 (Q-015): new entity `ReferenceRangeSetting` (user-defined
/// reference range per horse and measurement type, F-MESS-04) and `Horse.referenceRanges`.
///
/// CloudKit rules (SPEC section 2, F-ARCH-08) are enforced by `CloudKitComplianceTests`.
/// Only additive changes are allowed, each through a new `VersionedSchema` and `EquiMigrationPlan`.
public enum EquiSchemaV2: VersionedSchema {
  public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

  public static var models: [any PersistentModel.Type] {
    syncedModels + localOnlyModels
  }

  /// Models stored in the main store, which is synced via CloudKit once `cloudSyncEnabled` is on.
  public static var syncedModels: [any PersistentModel.Type] {
    [
      Horse.self,
      Stable.self,
      StableAssignment.self,
      BodyMeasurement.self,
      ReferenceRangeSetting.self,
      Feed.self,
      FeedingPlanItem.self,
      FeedingLog.self,
      SymptomEntry.self,
      Condition.self,
      Treatment.self,
      Medication.self,
      Contact.self,
      ReminderRule.self,
      Attachment.self,
      TrainingSession.self,
    ]
  }

  /// Models that never leave the device (own local store, never synced).
  public static var localOnlyModels: [any PersistentModel.Type] {
    [WeatherDay.self]
  }
}

/// The current schema version used by the app.
public typealias CurrentSchema = EquiSchemaV2

// Stable names for the current schema version. Feature code uses these, never `EquiSchemaVn.X`.
public typealias Horse = EquiSchemaV2.Horse
public typealias Stable = EquiSchemaV2.Stable
public typealias StableAssignment = EquiSchemaV2.StableAssignment
public typealias BodyMeasurement = EquiSchemaV2.BodyMeasurement
public typealias Feed = EquiSchemaV2.Feed
public typealias FeedingPlanItem = EquiSchemaV2.FeedingPlanItem
public typealias FeedingLog = EquiSchemaV2.FeedingLog
public typealias SymptomEntry = EquiSchemaV2.SymptomEntry
public typealias Condition = EquiSchemaV2.Condition
public typealias Treatment = EquiSchemaV2.Treatment
public typealias Medication = EquiSchemaV2.Medication
public typealias Contact = EquiSchemaV2.Contact
public typealias ReminderRule = EquiSchemaV2.ReminderRule
public typealias Attachment = EquiSchemaV2.Attachment
public typealias WeatherDay = EquiSchemaV2.WeatherDay
public typealias TrainingSession = EquiSchemaV2.TrainingSession
public typealias ReferenceRangeSetting = EquiSchemaV2.ReferenceRangeSetting

/// Common bookkeeping fields of every entity (SPEC section 3, F-TEIL-02).
public protocol EquiRecord: PersistentModel {
  var id: UUID { get }
  var createdAt: Date { get }
  var updatedAt: Date { get set }
  /// Display name of the creator; unused until sharing exists (F-TEIL-02).
  var createdBy: String? { get set }
  /// Display name of the last editor; unused until sharing exists (F-TEIL-02).
  var lastModifiedBy: String? { get set }
}

extension EquiRecord {
  /// Marks the record as changed. Call before saving an edit.
  public func touch(now: Date = .now) {
    updatedAt = now
  }
}

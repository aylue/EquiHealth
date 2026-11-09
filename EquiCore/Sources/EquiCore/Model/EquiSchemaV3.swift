import Foundation
import SwiftData

/// Schema version 3 – the current data model.
///
/// Additive change against V2 (Q-033): `FeedingLog.kindRaw` and `FeedingLog.mealRaw`, so a day's
/// feeding can deviate from a plan position (amount changed or left out), not only add extras.
///
/// CloudKit rules (SPEC section 2, F-ARCH-08) are enforced by `CloudKitComplianceTests`.
/// Only additive changes are allowed, each through a new `VersionedSchema` and `EquiMigrationPlan`.
public enum EquiSchemaV3: VersionedSchema {
  public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

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
public typealias CurrentSchema = EquiSchemaV3

// Stable names for the current schema version. Feature code uses these, never `EquiSchemaVn.X`.
public typealias Horse = EquiSchemaV3.Horse
public typealias Stable = EquiSchemaV3.Stable
public typealias StableAssignment = EquiSchemaV3.StableAssignment
public typealias BodyMeasurement = EquiSchemaV3.BodyMeasurement
public typealias Feed = EquiSchemaV3.Feed
public typealias FeedingPlanItem = EquiSchemaV3.FeedingPlanItem
public typealias FeedingLog = EquiSchemaV3.FeedingLog
public typealias SymptomEntry = EquiSchemaV3.SymptomEntry
public typealias Condition = EquiSchemaV3.Condition
public typealias Treatment = EquiSchemaV3.Treatment
public typealias Medication = EquiSchemaV3.Medication
public typealias Contact = EquiSchemaV3.Contact
public typealias ReminderRule = EquiSchemaV3.ReminderRule
public typealias Attachment = EquiSchemaV3.Attachment
public typealias WeatherDay = EquiSchemaV3.WeatherDay
public typealias TrainingSession = EquiSchemaV3.TrainingSession
public typealias ReferenceRangeSetting = EquiSchemaV3.ReferenceRangeSetting

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

import Foundation
import SwiftData

/// Schema version 1 of the EquiHealth data model.
///
/// CloudKit rules (SPEC section 2, F-ARCH-08), enforced by `CloudKitComplianceTests`:
/// every attribute is optional or has a default value, no unique constraints, every
/// relationship is optional and has an inverse, large binary data uses external storage.
/// After phase 0 only additive changes are allowed, through a new `VersionedSchema`.
public enum EquiSchemaV1: VersionedSchema {
  public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

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

// Stable names for the current schema version. Feature code uses these, never `EquiSchemaV1.X`.
public typealias Horse = EquiSchemaV1.Horse
public typealias Stable = EquiSchemaV1.Stable
public typealias StableAssignment = EquiSchemaV1.StableAssignment
public typealias BodyMeasurement = EquiSchemaV1.BodyMeasurement
public typealias Feed = EquiSchemaV1.Feed
public typealias FeedingPlanItem = EquiSchemaV1.FeedingPlanItem
public typealias FeedingLog = EquiSchemaV1.FeedingLog
public typealias SymptomEntry = EquiSchemaV1.SymptomEntry
public typealias Condition = EquiSchemaV1.Condition
public typealias Treatment = EquiSchemaV1.Treatment
public typealias Medication = EquiSchemaV1.Medication
public typealias Contact = EquiSchemaV1.Contact
public typealias ReminderRule = EquiSchemaV1.ReminderRule
public typealias Attachment = EquiSchemaV1.Attachment
public typealias WeatherDay = EquiSchemaV1.WeatherDay
public typealias TrainingSession = EquiSchemaV1.TrainingSession

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

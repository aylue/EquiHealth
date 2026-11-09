import Foundation
import SwiftData

/// Schema version 1 of the EquiHealth data model. FROZEN: never change; see `EquiSchemaV2` for the current model.
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

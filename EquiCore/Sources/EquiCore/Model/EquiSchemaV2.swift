import Foundation
import SwiftData

/// Schema version 2. FROZEN: never change; see `EquiSchemaV3` for the current model.
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

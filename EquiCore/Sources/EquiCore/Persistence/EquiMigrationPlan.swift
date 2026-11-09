import SwiftData

/// Migration plan of the EquiHealth store. Each new schema version gets an entry in `schemas`
/// and a stage; only additive changes are allowed (F-ARCH-08), so stages are lightweight.
public enum EquiMigrationPlan: SchemaMigrationPlan {
  public static var schemas: [any VersionedSchema.Type] {
    [EquiSchemaV1.self, EquiSchemaV2.self, EquiSchemaV3.self]
  }

  public static var stages: [MigrationStage] {
    [migrateV1toV2, migrateV2toV3]
  }

  /// V1 → V2: adds `ReferenceRangeSetting` and `Horse.referenceRanges` (Q-015).
  static let migrateV1toV2 = MigrationStage.lightweight(fromVersion: EquiSchemaV1.self, toVersion: EquiSchemaV2.self)

  /// V2 → V3: adds `FeedingLog.kindRaw` and `FeedingLog.mealRaw` (Q-033).
  static let migrateV2toV3 = MigrationStage.lightweight(fromVersion: EquiSchemaV2.self, toVersion: EquiSchemaV3.self)
}

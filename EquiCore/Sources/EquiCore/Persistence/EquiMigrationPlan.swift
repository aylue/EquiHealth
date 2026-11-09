import SwiftData

/// Migration plan of the EquiHealth store. Add new schema versions to `schemas` and a
/// lightweight stage per version; only additive changes are allowed (F-ARCH-08).
public enum EquiMigrationPlan: SchemaMigrationPlan {
  public static var schemas: [any VersionedSchema.Type] {
    [EquiSchemaV1.self]
  }

  public static var stages: [MigrationStage] {
    []
  }
}

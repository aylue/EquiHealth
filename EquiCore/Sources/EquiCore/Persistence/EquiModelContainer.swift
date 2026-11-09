import Foundation
import SwiftData

/// Builds the app's `ModelContainer` (F-ARCH-05, F-ARCH-06).
///
/// Two stores: the main store with all user data (CloudKit-ready, local while
/// `FeatureFlags.cloudSyncEnabled` is `false`) and a local-only weather cache.
public enum EquiModelContainer {
  public static let mainStoreName = "EquiHealth"
  public static let weatherStoreName = "WeatherCache"

  /// CloudKit setting of the main store. `.none` while sync is disabled.
  public static var mainStoreCloudKitDatabase: ModelConfiguration.CloudKitDatabase {
    FeatureFlags.cloudSyncEnabled ? .private(FeatureFlags.cloudKitContainerIdentifier) : .none
  }

  public static func make(inMemory: Bool = false) throws -> ModelContainer {
    let main = ModelConfiguration(
      mainStoreName,
      schema: Schema(EquiSchemaV1.syncedModels),
      isStoredInMemoryOnly: inMemory,
      allowsSave: true,
      cloudKitDatabase: mainStoreCloudKitDatabase
    )
    let weather = ModelConfiguration(
      weatherStoreName,
      schema: Schema(EquiSchemaV1.localOnlyModels),
      isStoredInMemoryOnly: inMemory,
      allowsSave: true,
      cloudKitDatabase: .none
    )
    return try ModelContainer(
      for: Schema(versionedSchema: EquiSchemaV1.self),
      migrationPlan: EquiMigrationPlan.self,
      configurations: [main, weather]
    )
  }
}

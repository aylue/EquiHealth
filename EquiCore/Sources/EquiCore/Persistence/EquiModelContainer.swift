import Foundation
import SwiftData

/// Builds the app's `ModelContainer` (F-ARCH-05, F-ARCH-06).
///
/// Two stores: the main store with all user data (CloudKit-ready, local while
/// `FeatureFlags.cloudSyncEnabled` is `false`) and a local-only weather cache.
public enum EquiModelContainer {
  public static let mainStoreName = "EquiHealth"
  public static let weatherStoreName = "WeatherCache"

  /// CloudKit container of the main store, or `nil` for a local store. In-memory stores (tests,
  /// UI tests) never sync, even with sync enabled.
  static func mainStoreContainerIdentifier(syncEnabled: Bool, inMemory: Bool) -> String? {
    syncEnabled && !inMemory ? FeatureFlags.cloudKitContainerIdentifier : nil
  }

  /// CloudKit setting of the main store. `.none` while sync is disabled (F-ARCH-06).
  static func mainStoreCloudKitDatabase(inMemory: Bool) -> ModelConfiguration.CloudKitDatabase {
    mainStoreContainerIdentifier(syncEnabled: FeatureFlags.cloudSyncEnabled, inMemory: inMemory)
      .map { .private($0) } ?? .none
  }

  /// - Parameters:
  ///   - inMemory: keep everything in memory (tests, UI tests).
  ///   - storeDirectory: directory for the store files; `nil` uses the default location.
  public static func make(inMemory: Bool = false, storeDirectory: URL? = nil) throws -> ModelContainer {
    let configurations = configurations(
      synced: CurrentSchema.syncedModels, localOnly: CurrentSchema.localOnlyModels,
      inMemory: inMemory, storeDirectory: storeDirectory)
    return try ModelContainer(
      for: Schema(versionedSchema: CurrentSchema.self),
      migrationPlan: EquiMigrationPlan.self,
      configurations: configurations
    )
  }

  /// Store configurations for the given model lists. Internal so migration tests can build
  /// stores of older schema versions at the same location.
  static func configurations(
    synced: [any PersistentModel.Type], localOnly: [any PersistentModel.Type],
    inMemory: Bool, storeDirectory: URL?
  ) -> [ModelConfiguration] {
    if let storeDirectory, !inMemory {
      return [
        ModelConfiguration(
          mainStoreName, schema: Schema(synced),
          url: storeDirectory.appending(path: "\(mainStoreName).store"),
          cloudKitDatabase: mainStoreCloudKitDatabase(inMemory: false)),
        ModelConfiguration(
          weatherStoreName, schema: Schema(localOnly),
          url: storeDirectory.appending(path: "\(weatherStoreName).store"),
          cloudKitDatabase: .none),
      ]
    }
    return [
      ModelConfiguration(
        mainStoreName, schema: Schema(synced), isStoredInMemoryOnly: inMemory, allowsSave: true,
        cloudKitDatabase: mainStoreCloudKitDatabase(inMemory: inMemory)),
      ModelConfiguration(
        weatherStoreName, schema: Schema(localOnly), isStoredInMemoryOnly: inMemory, allowsSave: true,
        cloudKitDatabase: .none),
    ]
  }
}

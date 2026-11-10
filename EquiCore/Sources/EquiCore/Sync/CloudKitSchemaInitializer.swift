import CoreData
import Foundation
import SwiftData

/// Creates the CloudKit schema in the development environment once, before the first deployment to
/// production (ENABLE_CLOUDKIT.md, step "Schema in CloudKit anlegen").
///
/// SwiftData does not expose `initializeCloudKitSchema`, so a Core Data container with the same model is
/// used. Only callable when `FeatureFlags.cloudSyncEnabled` is `true`; requires the iCloud entitlement.
public enum CloudKitSchemaInitializer {
  public enum InitializerError: Error, Equatable {
    case syncDisabled
    case modelUnavailable
  }

  /// - Parameter storeDirectory: a scratch directory; the store created there can be deleted afterwards.
  public static func initializeDevelopmentSchema(storeDirectory: URL) throws {
    guard FeatureFlags.cloudSyncEnabled else { throw InitializerError.syncDisabled }
    guard let model = NSManagedObjectModel.makeManagedObjectModel(for: CurrentSchema.syncedModels) else {
      throw InitializerError.modelUnavailable
    }
    let description = NSPersistentStoreDescription(
      url: storeDirectory.appending(path: "CloudKitSchemaInit.store"))
    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
      containerIdentifier: FeatureFlags.cloudKitContainerIdentifier)
    description.shouldAddStoreAsynchronously = false
    let container = NSPersistentCloudKitContainer(name: EquiModelContainer.mainStoreName, managedObjectModel: model)
    container.persistentStoreDescriptions = [description]
    var loadError: (any Error)?
    container.loadPersistentStores { _, error in loadError = error }
    if let loadError { throw loadError }
    try container.initializeCloudKitSchema(options: [])
    for store in container.persistentStoreCoordinator.persistentStores {
      try container.persistentStoreCoordinator.remove(store)
    }
  }
}

/// Central switches for features that require a paid Apple Developer Program membership
/// (F-ARCH-06). All flags stay `false` until such an account exists; see `ENABLE_CLOUDKIT.md`.
public enum FeatureFlags {
  /// Sync user data through the private CloudKit database (F-SYNC-01). Requires iCloud entitlement.
  public static let cloudSyncEnabled = false
  /// Share one CloudKit container and App Group with the training app (F-TRAIN-01).
  public static let sharedTrainingContainerEnabled = false
  /// Share a horse with other Apple accounts via `CKShare` (F-TEIL-03, F-TEIL-04).
  public static let sharingEnabled = false
  /// Home Screen widgets; need an App Group for data access (F-UI-08).
  public static let widgetsEnabled = false

  /// CloudKit container identifier used once `cloudSyncEnabled` is switched on.
  // ANNAHME: Container-ID folgt dem Bundle-Präfix; beim Aktivieren anpassen (ENABLE_CLOUDKIT.md).
  public static let cloudKitContainerIdentifier = "iCloud.de.aylu.EquiHealth"
  /// App Group shared with the training app once `sharedTrainingContainerEnabled` is on.
  public static let appGroupIdentifier = "group.de.aylu.EquiHealth"
}

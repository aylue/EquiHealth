import Foundation

/// iCloud account state as reported by CloudKit, mapped to what the app needs (F-SYNC-03).
public enum CloudAccountState: Sendable, Equatable {
  case available
  case noAccount
  case restricted
  /// Account exists but CloudKit cannot be used right now (e.g. temporarily unavailable).
  case temporarilyUnavailable
  case couldNotDetermine
}

/// Sync state shown in Settings (F-SYNC-02, F-SYNC-03).
public enum SyncStatus: Sendable, Equatable {
  /// `FeatureFlags.cloudSyncEnabled` is `false`: "noch nicht verfügbar" (SPEC 4.10).
  case notAvailable
  /// Sync is enabled but not yet checked.
  case checking
  /// Sync runs; `lastSync` is the end of the last successful import or export.
  case active(lastSync: Date?)
  /// Sync is enabled, but there is no usable iCloud account. Data stays on the device (F-SYNC-02).
  case accountUnavailable(CloudAccountState)
  /// The last sync event failed; sync is retried automatically.
  case failed(lastSync: Date?)

  /// Derives the status. `isEnabled` is a parameter (not the flag) so both paths are testable.
  public static func evaluate(
    isEnabled: Bool, account: CloudAccountState?, lastSuccessfulSync: Date?, lastEventFailed: Bool
  ) -> SyncStatus {
    guard isEnabled else { return .notAvailable }
    guard let account else { return .checking }
    guard account == .available else { return .accountUnavailable(account) }
    return lastEventFailed ? .failed(lastSync: lastSuccessfulSync) : .active(lastSync: lastSuccessfulSync)
  }
}

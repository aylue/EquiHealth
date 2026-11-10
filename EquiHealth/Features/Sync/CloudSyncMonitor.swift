import CloudKit
import CoreData
import EquiCore
import Foundation
import Observation

/// Watches the iCloud account and SwiftData's CloudKit events for the sync status in Settings
/// (F-SYNC-02, F-SYNC-03). Does nothing while `FeatureFlags.cloudSyncEnabled` is `false`: without the
/// iCloud entitlement, creating a `CKContainer` would crash the app.
@Observable
final class CloudSyncMonitor {
  private(set) var status: SyncStatus
  private var account: CloudAccountState?
  private var lastSuccessfulSync: Date?
  private var lastEventFailed = false

  @ObservationIgnored private let isEnabled: Bool
  @ObservationIgnored private var observers: [any NSObjectProtocol] = []

  init(isEnabled: Bool = FeatureFlags.cloudSyncEnabled) {
    self.isEnabled = isEnabled
    status = SyncStatus.evaluate(isEnabled: isEnabled, account: nil, lastSuccessfulSync: nil, lastEventFailed: false)
  }

  /// Starts observing; call once at launch.
  func start() async {
    guard isEnabled else { return }
    // ANNAHME: SwiftData meldet Sync-Ereignisse über die Benachrichtigung von NSPersistentCloudKitContainer,
    // weil es intern darauf aufsetzt. Beim Aktivieren auf einem Gerät prüfen (ENABLE_CLOUDKIT.md). Q-054.
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
      ) { [weak self] notification in
        guard
          let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event, let end = event.endDate
        else { return }
        let succeeded = event.succeeded
        MainActor.assumeIsolated { self?.record(end: end, succeeded: succeeded) }
      })
    observers.append(
      NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
        Task { @MainActor in await self?.refreshAccount() }
      })
    await refreshAccount()
  }

  func refreshAccount() async {
    guard isEnabled else { return }
    let container = CKContainer(identifier: FeatureFlags.cloudKitContainerIdentifier)
    let state: CloudAccountState
    switch try? await container.accountStatus() {
    case .available: state = .available
    case .noAccount: state = .noAccount
    case .restricted: state = .restricted
    case .temporarilyUnavailable: state = .temporarilyUnavailable
    default: state = .couldNotDetermine
    }
    account = state
    update()
  }

  private func record(end: Date, succeeded: Bool) {
    if succeeded { lastSuccessfulSync = max(lastSuccessfulSync ?? end, end) }
    lastEventFailed = !succeeded
    update()
  }

  private func update() {
    status = SyncStatus.evaluate(
      isEnabled: isEnabled, account: account, lastSuccessfulSync: lastSuccessfulSync, lastEventFailed: lastEventFailed)
  }
}

extension SyncStatus {
  var title: String {
    switch self {
    case .notAvailable: String(localized: "Noch nicht verfügbar")
    case .checking: String(localized: "Wird geprüft …")
    case .active: String(localized: "Aktiv")
    case .accountUnavailable: String(localized: "Kein iCloud-Konto")
    case .failed: String(localized: "Abgleich wird wiederholt")
    }
  }

  var explanation: String? {
    switch self {
    case .notAvailable:
      String(
        localized:
          "Die Synchronisierung zwischen iPhone und iPad kommt in einer späteren Version. Bis dahin bleiben alle Daten auf diesem Gerät. Sichere sie regelmäßig über „Backup“."
      )
    case .accountUnavailable(.noAccount):
      String(
        localized:
          "Melde dich in den iOS-Einstellungen bei iCloud an, um Daten zwischen Geräten abzugleichen. Die App funktioniert auch ohne."
      )
    case .accountUnavailable(.restricted):
      String(localized: "iCloud ist auf diesem Gerät eingeschränkt, zum Beispiel durch Bildschirmzeit.")
    case .accountUnavailable:
      String(localized: "iCloud ist gerade nicht erreichbar. Der Abgleich läuft nach, sobald möglich.")
    case .failed:
      String(localized: "Der letzte Abgleich ist fehlgeschlagen. Er wird automatisch wiederholt.")
    case .checking, .active:
      nil
    }
  }

  var lastSync: Date? {
    switch self {
    case .active(let date), .failed(let date): date
    default: nil
    }
  }
}

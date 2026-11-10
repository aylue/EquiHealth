import EquiCore
import SwiftUI
import UIKit
import UserNotifications

/// Settings (F-UI-01). Grows with later phases (export, backup).
struct SettingsView: View {
  @Environment(AppState.self) private var appState
  @Environment(ReminderNotificationService.self) private var notifications
  @Environment(CloudSyncMonitor.self) private var sync
  @Environment(\.openURL) private var openURL

  var body: some View {
    @Bindable var appState = appState
    List {
      Section {
        Toggle("Erinnerungen auf diesem Gerät", isOn: $appState.showsRemindersOnThisDevice)
          .accessibilityIdentifier("settings.showsReminders")
        Toggle("Mitteilung bei Ende der Turnier-Karenzzeit", isOn: $appState.notifiesCompetitionWithdrawalEnd)
          .accessibilityIdentifier("settings.withdrawalEnd")
        LabeledContent("Mitteilungen") {
          Text(statusText)
        }
        switch notifications.authorizationStatus {
        case .notDetermined:
          Button("Mitteilungen erlauben") {
            Task { await notifications.requestAuthorization() }
          }
          .accessibilityIdentifier("settings.allowNotifications")
        case .denied:
          Button("In den iOS-Einstellungen öffnen") {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
          }
        default:
          EmptyView()
        }
        #if DEBUG
          if ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting) {
            Button("Testerinnerung in 5 Sekunden") {
              Task { await notifications.scheduleTestNotification() }
            }
            .accessibilityIdentifier("settings.testNotification")
          }
        #endif
      } header: {
        Text("Erinnerungen")
      } footer: {
        Text(
          "Gilt nur für dieses Gerät. So vermeidest du doppelte Hinweise, wenn du die App auf iPhone und iPad nutzt."
        )
      }

      Section {
        NavigationLink {
          CSVExportView()
        } label: {
          Label("CSV-Export", systemImage: "tablecells")
        }
        .accessibilityIdentifier("settings.csvExport")
        NavigationLink {
          BackupView()
        } label: {
          LabeledContent {
            Text(
              appState.lastBackupDate.map { $0.formatted(date: .abbreviated, time: .omitted) }
                ?? String(localized: "noch keins"))
          } label: {
            Label("Backup", systemImage: "externaldrive")
          }
        }
        .accessibilityIdentifier("settings.backup")
      } header: {
        Text("Daten")
      }

      Section {
        // SPEC 4.10: "noch nicht verfügbar" until `cloudSyncEnabled` is on; F-SYNC-03 afterwards.
        LabeledContent("Status") {
          Text(sync.status.title)
        }
        .accessibilityIdentifier("settings.syncStatus")
        if FeatureFlags.cloudSyncEnabled {
          LabeledContent("Letzter Abgleich") {
            Text(sync.status.lastSync.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "–")
          }
        }
      } header: {
        Text("iCloud-Synchronisierung")
      } footer: {
        if let explanation = sync.status.explanation {
          Text(explanation)
        }
      }
      Section("Hinweis") {
        DisclaimerText()
      }
      Section("Über") {
        LabeledContent("Version", value: Self.version)
      }
      Section {
        Text(WeatherService.attribution)
        Link("Bright Sky (brightsky.dev)", destination: URL(string: "https://brightsky.dev")!)
        Link("Deutscher Wetterdienst – Open Data", destination: URL(string: "https://www.dwd.de/opendata")!)
      } header: {
        Text("Impressum und Quellen")
      } footer: {
        Text(
          "Wetterdaten stammen aus den offenen Daten des Deutschen Wetterdienstes und werden über Bright Sky abgerufen. Dabei werden nur auf 2 Nachkommastellen gerundete Stall-Koordinaten übertragen."
        )
      }
    }
    .navigationTitle("Einstellungen")
    .task { await notifications.refreshAuthorizationStatus() }
  }

  private var statusText: String {
    switch notifications.authorizationStatus {
    case .authorized, .provisional, .ephemeral: String(localized: "erlaubt")
    case .denied: String(localized: "abgelehnt")
    case .notDetermined: String(localized: "nicht gefragt")
    @unknown default: String(localized: "unbekannt")
    }
  }

  private static var version: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }
}

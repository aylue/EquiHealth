import EquiCore
import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// Settings (F-UI-01). Grows with later phases (export, backup).
struct SettingsView: View {
  @Environment(AppState.self) private var appState
  @Environment(ReminderNotificationService.self) private var notifications
  @Environment(CloudSyncMonitor.self) private var sync
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Horse.sortIndex) private var horses: [Horse]
  @State private var developerMessage: String?
  @State private var isGeneratingLargeData = false

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
      #if DEBUG
        developerSection
      #endif

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

  #if DEBUG
    /// NF-04: about 50,000 entries, generated off the main actor.
    private func generateLargeData() async {
      isGeneratingLargeData = true
      defer { isGeneratingLargeData = false }
      do {
        let summary = try await LargeDataGenerator(modelContainer: modelContext.container).generate()
        developerMessage = String(localized: "\(summary.entries) Einträge für \(summary.horses) Pferde erzeugt.")
      } catch {
        developerMessage = String(localized: "Testdaten konnten nicht erzeugt werden.")
      }
    }

    /// Fixed in UI tests so the samples are reproducible, otherwise new on every tap.
    private static var sampleSeed: UInt64 {
      ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting)
        ? 42 : UInt64(Date.now.timeIntervalSince1970)
    }

    /// F-TRAIN-06: sample sessions until the training app exists. Debug builds only.
    @ViewBuilder private var developerSection: some View {
      let horse = ActiveHorseSelection.resolve(storedID: appState.activeHorseID, in: horses)
      Section {
        Button("Beispiel-Trainingseinheiten erzeugen", systemImage: "figure.equestrian.sports") {
          guard let horse else { return }
          let sessions = TrainingSampleGenerator.insertSamples(
            for: horse, seed: Self.sampleSeed, in: modelContext)
          try? modelContext.save()
          developerMessage = String(localized: "\(sessions.count) Einheiten für \(horse.name) erzeugt.")
        }
        .disabled(horse == nil)
        .accessibilityIdentifier("developer.createTrainingSamples")
        Button("Beispiel-Einheiten löschen", systemImage: "trash", role: .destructive) {
          guard let horse else { return }
          TrainingSampleGenerator.removeSamples(for: horse, in: modelContext)
          try? modelContext.save()
          developerMessage = String(localized: "Beispiel-Einheiten von \(horse.name) gelöscht.")
        }
        .disabled(horse == nil)
        Button {
          Task { await generateLargeData() }
        } label: {
          HStack {
            Label("Testdaten erzeugen (10 Pferde, 10 Jahre)", systemImage: "cylinder.split.1x2")
            if isGeneratingLargeData {
              Spacer()
              ProgressView()
            }
          }
        }
        .disabled(isGeneratingLargeData)
        .accessibilityIdentifier("developer.generateLargeData")
        Button("Testdaten löschen", systemImage: "trash", role: .destructive) {
          Task {
            try? await LargeDataGenerator(modelContainer: modelContext.container).removeGeneratedData()
            developerMessage = String(localized: "Testdaten gelöscht.")
          }
        }
        .disabled(isGeneratingLargeData)
        if let developerMessage {
          Text(developerMessage).foregroundStyle(.secondary)
            .accessibilityIdentifier("developer.message")
        }
      } header: {
        Text("Entwickler")
      } footer: {
        Text(
          "Nur in Debug-Builds. Erzeugt 4 Wochen Beispiel-Einheiten für das aktive Pferd, bis die Trainings-App existiert."
        )
      }
    }
  #endif

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

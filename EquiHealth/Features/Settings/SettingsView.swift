import EquiCore
import SwiftUI

/// Settings (F-UI-01). Grows with later phases (reminders, export, backup).
struct SettingsView: View {
  var body: some View {
    List {
      Section("iCloud-Synchronisierung") {
        // SPEC 4.10: shown until `cloudSyncEnabled` is on.
        LabeledContent("Status") {
          Text(FeatureFlags.cloudSyncEnabled ? "Aktiv" : "Noch nicht verfügbar")
        }
        .accessibilityIdentifier("settings.syncStatus")
      }
      Section("Hinweis") {
        DisclaimerText()
      }
      Section("Über") {
        LabeledContent("Version", value: Self.version)
      }
    }
    .navigationTitle("Einstellungen")
  }

  private static var version: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }
}

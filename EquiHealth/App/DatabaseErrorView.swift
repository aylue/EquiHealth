import SwiftUI

/// Shown instead of the app when the database cannot be opened (Q-010). Nothing is deleted; the
/// store files stay untouched so the data can still be recovered.
struct DatabaseErrorView: View {
  let details: String
  @State private var showsDetails = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          ContentUnavailableView {
            Label("Daten konnten nicht geöffnet werden", systemImage: "exclamationmark.triangle")
          } description: {
            Text(
              "EquiHealth kann seine Datenbank gerade nicht öffnen. Es wurde nichts gelöscht."
            )
          }
          .accessibilityIdentifier("databaseError")
        }
        Section("Was du tun kannst") {
          Label("Beende die App ganz und öffne sie erneut.", systemImage: "arrow.clockwise")
          Label("Prüfe, ob auf dem Gerät genug Speicher frei ist.", systemImage: "internaldrive")
          Label(
            "Lösche die App nicht. Ohne Backup wären die Daten dann verloren. Ein Backup lässt sich nach einer Neuinstallation unter Einstellungen › Backup wiederherstellen.",
            systemImage: "externaldrive")
        }
        Section {
          DisclosureGroup("Technische Details", isExpanded: $showsDetails) {
            Text(details)
              .font(.footnote.monospaced())
              .textSelection(.enabled)
          }
        }
      }
      .navigationTitle("EquiHealth")
    }
  }
}

#Preview {
  DatabaseErrorView(details: "Beispiel")
}

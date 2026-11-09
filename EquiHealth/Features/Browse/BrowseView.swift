import EquiCore
import SwiftUI

/// "Durchsuchen" tab: health categories with colour and SF Symbol (SPEC section 5).
/// Further categories (Fütterung, Symptome, Behandlungen, Medikamente, Training) follow in later phases.
struct BrowseView: View {
  var body: some View {
    NavigationStack {
      ActiveHorseReader { horse in
        if let horse {
          List {
            Section("Kategorien") {
              NavigationLink {
                MeasurementsOverviewView(horse: horse)
              } label: {
                Label {
                  Text("Messwerte")
                } icon: {
                  Image(systemName: "chart.xyaxis.line").foregroundStyle(Color.categoryMeasurements)
                }
              }
              .accessibilityIdentifier("category.measurements")
            }
          }
        } else {
          NoHorseView()
        }
      }
      .navigationTitle("Durchsuchen")
      .appToolbar()
    }
  }
}

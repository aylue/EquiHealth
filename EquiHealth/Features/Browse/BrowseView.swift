import EquiCore
import SwiftUI

/// "Durchsuchen" tab: health categories with colour and SF Symbol (SPEC section 5).
/// Fütterung and Training follow in later phases.
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
              categoryLink(
                "Symptome und Krankheiten", systemImage: "cross.case", color: .categorySymptoms, id: "health"
              ) {
                HealthListView(horse: horse)
              }
              categoryLink("Behandlungen", systemImage: "stethoscope", color: .categoryTreatments, id: "treatments") {
                TreatmentsListView(horse: horse)
              }
              categoryLink("Medikamente", systemImage: "pills", color: .categoryMedications, id: "medications") {
                MedicationsListView(horse: horse)
              }
            }
            Section {
              categoryLink(
                "Zeitleiste", systemImage: "list.bullet.below.rectangle", color: .accentColor, id: "timeline"
              ) {
                HealthTimelineView(horse: horse)
              }
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

  private func categoryLink<Destination: View>(
    _ title: LocalizedStringKey, systemImage: String, color: Color, id: String,
    @ViewBuilder destination: @escaping () -> Destination
  ) -> some View {
    NavigationLink(destination: destination) {
      Label {
        Text(title)
      } icon: {
        Image(systemName: systemImage).foregroundStyle(color)
      }
    }
    .accessibilityIdentifier("category.\(id)")
  }
}

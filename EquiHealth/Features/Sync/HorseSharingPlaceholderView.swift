import EquiCore
import SwiftUI

/// Placeholder for sharing a horse with other Apple accounts (F-TEIL-03, F-TEIL-04). Only reachable when
/// `FeatureFlags.sharingEnabled` is `true`; the real implementation uses `CKShare` (see ENABLE_CLOUDKIT.md).
struct HorseSharingPlaceholderView: View {
  @Environment(\.dismiss) private var dismiss
  let horse: Horse

  var body: some View {
    let graph = HorseRecordGraph(horse: horse)
    NavigationStack {
      ContentUnavailableView {
        Label("Pferd teilen", systemImage: "person.2")
      } description: {
        Text(
          "Freigaben für Reitbeteiligung, Stall oder Tierarzt sind vorbereitet, aber noch nicht umgesetzt. Geteilt würden \(graph.recordCount) Einträge von \(horse.name)."
        )
      }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") { dismiss() }
        }
      }
    }
  }
}

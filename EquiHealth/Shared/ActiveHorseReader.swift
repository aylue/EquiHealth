import EquiCore
import SwiftData
import SwiftUI

/// Resolves the active horse from the stored selection and the non-archived horses (F-PFERD-02).
struct ActiveHorseReader<Content: View>: View {
  @Environment(AppState.self) private var appState
  @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.sortIndex) private var horses: [Horse]

  @ViewBuilder let content: (Horse?) -> Content

  var body: some View {
    content(ActiveHorseSelection.resolve(storedID: appState.activeHorseID, in: horses))
  }
}

/// Shown wherever an active horse is required but none exists (F-UI-05).
struct NoHorseView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    ContentUnavailableView {
      Label("Noch keine Pferde", systemImage: "list.bullet.clipboard")
    } description: {
      Text("Lege ein Pferd an, um Messwerte, Fütterung und Gesundheit zu erfassen.")
    } actions: {
      Button("Erstes Pferd anlegen") { appState.sheet = .newHorse }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("createFirstHorse")
    }
  }
}

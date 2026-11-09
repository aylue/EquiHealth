import EquiCore
import SwiftData
import SwiftUI

extension View {
  /// Navigation bar of every tab (F-UI-01, F-UI-02): horse switcher on the left,
  /// global "+" menu and profile menu on the right.
  func appToolbar() -> some View {
    modifier(AppToolbar())
  }
}

private struct AppToolbar: ViewModifier {
  @Environment(AppState.self) private var appState
  @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.sortIndex) private var horses: [Horse]

  private var activeHorse: Horse? {
    ActiveHorseSelection.resolve(storedID: appState.activeHorseID, in: horses)
  }

  func body(content: Content) -> some View {
    content.toolbar {
      ToolbarItem(placement: .topBarLeading) { horseSwitcher }
      ToolbarItem(placement: .topBarTrailing) { addMenu }
      ToolbarItem(placement: .topBarTrailing) { profileMenu }
    }
  }

  @ViewBuilder private var horseSwitcher: some View {
    if let activeHorse {
      Menu {
        Picker(
          "Pferd",
          selection: Binding(
            get: { activeHorse.id },
            set: { appState.activeHorseID = $0 })
        ) {
          ForEach(horses) { horse in
            Text(horse.name).tag(horse.id)
          }
        }
        .pickerStyle(.inline)
        Divider()
        Button("Pferde verwalten", systemImage: "list.bullet") { appState.sheet = .horseManagement }
      } label: {
        HStack(spacing: 8) {
          HorseAvatar(photoData: activeHorse.photoData, size: 28)
          Text(activeHorse.name)
            .lineLimit(1)
            .fontWeight(.semibold)
        }
      }
      .accessibilityLabel(Text("Aktives Pferd: \(activeHorse.name)"))
      .accessibilityHint(Text("Wechselt das angezeigte Pferd"))
      .accessibilityIdentifier("horseSwitcher")
    }
  }

  private var addMenu: some View {
    Menu {
      Menu("Messwert", systemImage: "chart.xyaxis.line") {
        ForEach(MeasurementType.allCases) { type in
          Button(type.title, systemImage: type.systemImage) { appState.sheet = .newMeasurement(type) }
        }
      }
      Button("Gewicht schätzen", systemImage: "function") { appState.sheet = .estimateWeight }
      Divider()
      Button("Symptom", systemImage: "cross.case") { appState.sheet = .newSymptom }
      Button("Behandlung", systemImage: "stethoscope") { appState.sheet = .newTreatment }
      Button("Krankheit", systemImage: "heart.text.clipboard") { appState.sheet = .newCondition }
    } label: {
      Label("Hinzufügen", systemImage: "plus")
    }
    .disabled(activeHorse == nil)
    .accessibilityIdentifier("addMenu")
  }

  private var profileMenu: some View {
    Menu {
      Button("Pferdeprofil", systemImage: "info.circle") { appState.sheet = .horseProfile }
        .disabled(activeHorse == nil)
      Button("Pferdeverwaltung", systemImage: "list.bullet") { appState.sheet = .horseManagement }
      Button("Ställe", systemImage: "house") { appState.sheet = .stables }
      Button("Kontakte", systemImage: "person.crop.rectangle.stack") { appState.sheet = .contacts }
      Divider()
      Button("Einstellungen", systemImage: "gear") { appState.sheet = .settings }
    } label: {
      Label("Profil", systemImage: "person.crop.circle")
    }
    .accessibilityIdentifier("profileMenu")
  }
}

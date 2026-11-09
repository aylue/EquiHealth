import EquiCore
import SwiftData
import SwiftUI

/// List of all horses: create, reorder, archive and delete (F-PFERD-01, F-PFERD-05).
struct HorseManagementView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AppState.self) private var appState
  @Query(sort: \Horse.sortIndex) private var horses: [Horse]

  @State private var showsNewHorse = false
  @State private var horseToDelete: Horse?

  private var activeHorses: [Horse] { horses.filter { !$0.isArchived } }
  private var archivedHorses: [Horse] { horses.filter(\.isArchived) }

  var body: some View {
    List {
      if horses.isEmpty {
        ContentUnavailableView {
          Label("Noch keine Pferde", systemImage: "list.bullet.clipboard")
        } actions: {
          Button("Erstes Pferd anlegen") { showsNewHorse = true }
            .buttonStyle(.borderedProminent)
        }
      }
      if !activeHorses.isEmpty {
        Section("Pferde") {
          ForEach(activeHorses) { horse in
            row(horse)
              .swipeActions(edge: .trailing) {
                Button("Löschen", systemImage: "trash", role: .destructive) { horseToDelete = horse }
                Button("Archivieren", systemImage: "archivebox") { setArchived(horse, true) }
              }
          }
          .onMove(perform: move)
        }
      }
      if !archivedHorses.isEmpty {
        Section {
          ForEach(archivedHorses) { horse in
            row(horse)
              .swipeActions(edge: .trailing) {
                Button("Löschen", systemImage: "trash", role: .destructive) { horseToDelete = horse }
                Button("Wiederherstellen", systemImage: "arrow.uturn.backward") { setArchived(horse, false) }
              }
          }
        } header: {
          Text("Archiviert")
        } footer: {
          Text("Archivierte Pferde erscheinen nicht im Pferde-Umschalter. Ihre Daten bleiben erhalten.")
        }
      }
    }
    .navigationTitle("Pferdeverwaltung")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) { EditButton() }
      ToolbarItem(placement: .primaryAction) {
        Button("Pferd hinzufügen", systemImage: "plus") { showsNewHorse = true }
          .accessibilityIdentifier("addHorse")
      }
    }
    .sheet(isPresented: $showsNewHorse) {
      HorseFormView(horse: nil)
    }
    .confirmationDialog(
      "Pferd endgültig löschen?", isPresented: isConfirmingDelete, titleVisibility: .visible,
      presenting: horseToDelete
    ) { horse in
      Button("„\(horse.name)“ löschen", role: .destructive) { delete(horse) }
    } message: { _ in
      Text(
        "Alle Messwerte und Einträge dieses Pferdes werden ebenfalls gelöscht. Das lässt sich nicht rückgängig machen.")
    }
  }

  private var isConfirmingDelete: Binding<Bool> {
    Binding(get: { horseToDelete != nil }, set: { if !$0 { horseToDelete = nil } })
  }

  private func row(_ horse: Horse) -> some View {
    NavigationLink {
      HorseProfileView(horse: horse)
    } label: {
      HStack(spacing: 12) {
        HorseAvatar(photoData: horse.photoData, size: 40)
        VStack(alignment: .leading) {
          Text(horse.name)
          if let callName = horse.callName {
            Text(callName).font(.subheadline).foregroundStyle(.secondary)
          }
        }
        if horse.id == appState.activeHorseID && !horse.isArchived {
          Spacer()
          Image(systemName: "checkmark")
            .foregroundStyle(.tint)
            .accessibilityLabel("Aktiv")
        }
      }
    }
  }

  private func move(from source: IndexSet, to destination: Int) {
    var ordered = activeHorses
    ordered.move(fromOffsets: source, toOffset: destination)
    for (index, horse) in ordered.enumerated() where horse.sortIndex != index {
      horse.sortIndex = index
      horse.touch()
    }
    try? modelContext.save()
  }

  private func setArchived(_ horse: Horse, _ archived: Bool) {
    horse.isArchived = archived
    horse.touch()
    try? modelContext.save()
  }

  private func delete(_ horse: Horse) {
    modelContext.delete(horse)
    try? modelContext.save()
    horseToDelete = nil
  }
}

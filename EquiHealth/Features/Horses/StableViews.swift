import EquiCore
import SwiftData
import SwiftUI

/// Stable management (F-PFERD-04). Stables are shared master data (F-TEIL-01).
struct StablesView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Stable.name) private var stables: [Stable]
  @State private var editing: StableEditTarget?
  @State private var stableToDelete: Stable?

  var body: some View {
    List {
      if stables.isEmpty {
        ContentUnavailableView {
          Label("Keine Ställe", systemImage: "house")
        } description: {
          Text("Ställe bestimmen später den Ort für Wetterdaten.")
        } actions: {
          Button("Stall anlegen") { editing = .new }
            .buttonStyle(.borderedProminent)
        }
      }
      ForEach(stables) { stable in
        Button {
          editing = .existing(stable)
        } label: {
          VStack(alignment: .leading) {
            Text(stable.name).foregroundStyle(.primary)
            let horses = currentHorses(of: stable)
            if let locality = stable.locality {
              Text(locality).font(.subheadline).foregroundStyle(.secondary)
            }
            if !horses.isEmpty {
              Text(horses.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        .swipeActions {
          Button("Löschen", systemImage: "trash", role: .destructive) { stableToDelete = stable }
        }
      }
    }
    .navigationTitle("Ställe")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Stall hinzufügen", systemImage: "plus") { editing = .new }
      }
    }
    .sheet(item: $editing) { target in
      StableFormView(stable: target.stable)
    }
    .confirmationDialog(
      "Stall löschen?",
      isPresented: Binding(get: { stableToDelete != nil }, set: { if !$0 { stableToDelete = nil } }),
      titleVisibility: .visible, presenting: stableToDelete
    ) { stable in
      Button("„\(stable.name)“ löschen", role: .destructive) {
        modelContext.delete(stable)
        try? modelContext.save()
      }
    } message: { _ in
      Text("Alle Zuordnungen von Pferden zu diesem Stall werden ebenfalls gelöscht.")
    }
  }

  private func currentHorses(of stable: Stable) -> [String] {
    (stable.assignments ?? []).filter { $0.validUntil == nil }.compactMap { $0.horse?.name }.sorted()
  }
}

enum StableEditTarget: Identifiable {
  case new
  case existing(Stable)

  var id: String {
    switch self {
    case .new: "new"
    case .existing(let stable): stable.id.uuidString
    }
  }

  var stable: Stable? {
    if case .existing(let stable) = self { return stable }
    return nil
  }
}

/// Create or edit a stable.
struct StableFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let stable: Stable?
  var onCreate: ((Stable) -> Void)?

  @State private var name: String
  @State private var locality: String

  init(stable: Stable?, onCreate: ((Stable) -> Void)? = nil) {
    self.stable = stable
    self.onCreate = onCreate
    _name = State(initialValue: stable?.name ?? "")
    _locality = State(initialValue: stable?.locality ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
            .accessibilityIdentifier("stable.name")
          TextField("Ort", text: $locality)
        } footer: {
          // ANNAHME: Koordinaten (CoreLocation/MapKit-Suche) kommen mit dem Wetter in Phase 5. Q-017.
          Text("Der genaue Standort für Wetterdaten wird in einer späteren Version ergänzt.")
        }
      }
      .navigationTitle(stable == nil ? "Neuer Stall" : "Stall bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(name.nilIfBlank == nil)
            .accessibilityIdentifier("save")
        }
      }
    }
  }

  private func save() {
    guard let trimmed = name.nilIfBlank else { return }
    if let stable {
      stable.name = trimmed
      stable.locality = locality.nilIfBlank
      stable.touch()
    } else {
      let new = Stable(name: trimmed)
      new.locality = locality.nilIfBlank
      modelContext.insert(new)
      onCreate?(new)
    }
    try? modelContext.save()
    dismiss()
  }
}

/// Assigns a horse to a stable or records a move (F-PFERD-04).
struct StableAssignmentForm: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let horse: Horse

  @Query(sort: \Stable.name) private var stables: [Stable]
  @State private var selectedStableID: UUID?
  @State private var date = Date.now
  @State private var showsNewStable = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          if stables.isEmpty {
            Text("Noch keine Ställe angelegt.").foregroundStyle(.secondary)
          } else {
            Picker("Stall", selection: $selectedStableID) {
              Text("Bitte wählen").tag(UUID?.none)
              ForEach(stables) { stable in
                Text(stable.name).tag(Optional(stable.id))
              }
            }
          }
          Button("Neuen Stall anlegen", systemImage: "plus") { showsNewStable = true }
        }
        Section {
          DatePicker("Ab", selection: $date, displayedComponents: .date)
        } footer: {
          if horse.stableAssignment() != nil {
            Text("Die bisherige Zuordnung endet an diesem Tag.")
          }
        }
      }
      .navigationTitle(horse.stableAssignment() == nil ? "Stall zuordnen" : "Umzug")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(selectedStableID == nil)
        }
      }
      .sheet(isPresented: $showsNewStable) {
        StableFormView(stable: nil) { selectedStableID = $0.id }
      }
    }
  }

  private func save() {
    guard let stable = stables.first(where: { $0.id == selectedStableID }) else { return }
    horse.move(to: stable, on: Calendar.current.startOfDay(for: date), in: modelContext)
    try? modelContext.save()
    dismiss()
  }
}

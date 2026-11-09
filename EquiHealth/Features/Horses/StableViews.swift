import CoreLocation
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
            if stable.latitude == nil {
              Label("Kein Standort für Wetterdaten", systemImage: "location.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
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
  @State private var coordinate: CLLocationCoordinate2D?

  init(stable: Stable?, onCreate: ((Stable) -> Void)? = nil) {
    self.stable = stable
    self.onCreate = onCreate
    _name = State(initialValue: stable?.name ?? "")
    _locality = State(initialValue: stable?.locality ?? "")
    if let latitude = stable?.latitude, let longitude = stable?.longitude {
      _coordinate = State(initialValue: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
            .accessibilityIdentifier("stable.name")
          TextField("Ort", text: $locality)
        }
        StableLocationSection(coordinate: $coordinate, locality: $locality)
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
    let target = stable ?? Stable(name: trimmed)
    if stable == nil { modelContext.insert(target) }
    target.name = trimmed
    target.locality = locality.nilIfBlank
    target.latitude = coordinate?.latitude
    target.longitude = coordinate?.longitude
    target.touch()
    if stable == nil { onCreate?(target) }
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
  /// First assignment of a horse: the horse may have stood there before it was recorded (Q-042).
  @State private var startIsUnknown = true

  private var isFirstAssignment: Bool { (horse.stableAssignments ?? []).isEmpty }

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
          if isFirstAssignment {
            Toggle("Beginn unbekannt", isOn: $startIsUnknown.animation())
          }
          if !isFirstAssignment || !startIsUnknown {
            DatePicker("Ab", selection: $date, displayedComponents: .date)
          }
        } footer: {
          if horse.stableAssignment() != nil {
            Text("Die bisherige Zuordnung endet an diesem Tag.")
          } else if isFirstAssignment && startIsUnknown {
            Text("Das Pferd stand schon vor heute dort. Wetterdaten älterer Einträge nutzen dann diesen Stall.")
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
    let start =
      isFirstAssignment && startIsUnknown ? StableAssignment.unknownStart : Calendar.current.startOfDay(for: date)
    horse.move(to: stable, on: start, in: modelContext)
    try? modelContext.save()
    dismiss()
  }
}

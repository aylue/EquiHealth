import EquiCore
import SwiftData
import SwiftUI

/// "Symptome und Krankheiten" of one horse.
struct HealthListView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AppState.self) private var appState
  let horse: Horse

  var body: some View {
    let ongoing = horse.ongoingSymptoms
    let past = (horse.symptoms ?? []).filter { !$0.isOngoing }.sorted { $0.startDate > $1.startDate }
    let conditions = (horse.conditions ?? []).sorted {
      ($0.healedAt == nil ? 0 : 1, $0.name) < ($1.healedAt == nil ? 0 : 1, $1.name)
    }

    List {
      if ongoing.isEmpty && past.isEmpty && conditions.isEmpty {
        ContentUnavailableView {
          Label("Keine Einträge", systemImage: "cross.case")
        } description: {
          Text("Erfasse Symptome und Krankheiten über das Plus-Menü.")
        } actions: {
          Button("Symptom erfassen") { appState.sheet = .newSymptom }
            .buttonStyle(.borderedProminent)
        }
      }
      if !ongoing.isEmpty {
        Section("Laufende Symptome") {
          ForEach(ongoing) { symptom in
            OngoingSymptomRow(symptom: symptom)
          }
        }
      }
      if !conditions.isEmpty {
        Section("Krankheiten") {
          ForEach(conditions) { condition in
            NavigationLink {
              ConditionDetailView(condition: condition)
            } label: {
              ConditionRow(condition: condition)
            }
          }
          .onDelete { offsets in delete(offsets.map { conditions[$0] }) }
        }
      }
      if !past.isEmpty {
        Section("Abgeschlossene Symptome") {
          ForEach(past) { symptom in
            NavigationLink {
              SymptomDetailView(symptom: symptom)
            } label: {
              SymptomRow(symptom: symptom)
            }
          }
          .onDelete { offsets in delete(offsets.map { past[$0] }) }
        }
      }
    }
    .navigationTitle("Symptome und Krankheiten")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu("Hinzufügen", systemImage: "plus") {
          Button("Symptom", systemImage: "cross.case") { appState.sheet = .newSymptom }
          Button("Krankheit", systemImage: "heart.text.clipboard") { appState.sheet = .newCondition }
        }
      }
    }
  }

  private func delete(_ models: [any PersistentModel]) {
    for model in models { modelContext.delete(model) }
    try? modelContext.save()
  }
}

/// Ongoing symptom with a one-tap "Beenden" button (F-GESUND-03). The bordered button keeps
/// its own tap area inside the navigation row.
struct OngoingSymptomRow: View {
  @Environment(\.modelContext) private var modelContext
  let symptom: SymptomEntry

  var body: some View {
    NavigationLink {
      SymptomDetailView(symptom: symptom)
    } label: {
      HStack {
        SymptomRow(symptom: symptom)
        Spacer(minLength: 8)
        Button("Beenden") {
          symptom.endDate = max(.now, symptom.startDate)
          symptom.touch()
          try? modelContext.save()
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text("\(symptom.categoryTitle) beenden"))
        .accessibilityIdentifier("endSymptom")
      }
    }
  }
}

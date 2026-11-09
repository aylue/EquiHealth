import EquiCore
import SwiftUI

/// Timeline of symptoms, conditions and treatments per horse, filterable by kind (F-GESUND-06).
struct HealthTimelineView: View {
  @Environment(WeatherService.self) private var weather
  let horse: Horse
  @State private var kinds = Set(TimelineKind.allCases)
  @State private var weatherLookup = WeatherService.Lookup()

  var body: some View {
    let items = horse.timeline(kinds: kinds)
    let days = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }
      .sorted { $0.key > $1.key }

    List {
      if items.isEmpty {
        ContentUnavailableView(
          "Keine Einträge", systemImage: "list.bullet.below.rectangle",
          description: Text("Symptome, Krankheiten und Behandlungen erscheinen hier chronologisch."))
      }
      ForEach(days, id: \.key) { day, entries in
        Section {
          ForEach(entries) { item in
            row(for: item)
          }
        } header: {
          HStack {
            Text(day.formatted(date: .complete, time: .omitted))
            Spacer()
            WeatherInlineLabel(state: weatherLookup.states[day])
          }
        }
      }
      if weatherLookup.states.values.contains(where: { if case .weather = $0 { true } else { false } }) {
        Section {
        } footer: {
          Text(WeatherService.attribution)
        }
      }
    }
    .navigationTitle("Zeitleiste")
    .task(id: days.map(\.key)) {
      weatherLookup = await weather.lookup(horse: horse, days: days.map(\.key))
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          ForEach(TimelineKind.allCases, id: \.self) { kind in
            Toggle(
              kind.title,
              isOn: Binding(
                get: { kinds.contains(kind) },
                set: { isOn in
                  if isOn { kinds.insert(kind) } else { kinds.remove(kind) }
                }))
          }
        } label: {
          Label(
            "Filter",
            systemImage: kinds.count == TimelineKind.allCases.count
              ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityIdentifier("timeline.filter")
      }
    }
  }

  @ViewBuilder private func row(for item: TimelineItem) -> some View {
    switch item {
    case .symptom(let symptom):
      NavigationLink {
        SymptomDetailView(symptom: symptom)
      } label: {
        SymptomRow(symptom: symptom)
      }
      .accessibilityIdentifier("timeline.symptom")
    case .condition(let condition):
      NavigationLink {
        ConditionDetailView(condition: condition)
      } label: {
        ConditionRow(condition: condition)
      }
      .accessibilityIdentifier("timeline.condition")
    case .treatment(let treatment):
      NavigationLink {
        TreatmentDetailView(treatment: treatment)
      } label: {
        TreatmentRow(treatment: treatment)
      }
      .accessibilityIdentifier("timeline.treatment")
    }
  }
}

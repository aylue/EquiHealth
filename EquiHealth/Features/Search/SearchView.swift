import EquiCore
import SwiftData
import SwiftUI

/// "Suche" tab: full-text search across notes, symptoms, conditions, treatments and medications,
/// for all horses (SPEC 5, Q-029). Runs off the main actor (`FullTextSearch`).
struct SearchView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var query = ""
  @State private var hits: [SearchHit] = []
  @State private var searchedQuery = ""
  @State private var isSearching = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(SearchHitKind.allCases, id: \.self) { kind in
          let group = hits.filter { $0.kind == kind }
          if !group.isEmpty {
            Section(kind.sectionTitle) {
              ForEach(group) { hit in
                NavigationLink {
                  SearchHitDestination(hit: hit)
                } label: {
                  SearchHitRow(hit: hit)
                }
                .accessibilityIdentifier("search.hit")
              }
            }
          }
        }
      }
      .overlay {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
          ContentUnavailableView {
            Label("Suche", systemImage: "magnifyingglass")
          } description: {
            Text("Durchsuche Notizen, Symptome, Krankheiten, Behandlungen und Medikamente aller Pferde.")
          }
        } else if hits.isEmpty && !isSearching && searchedQuery == query {
          ContentUnavailableView.search(text: query)
        }
      }
      .navigationTitle("Suche")
      .appToolbar()
      .searchable(text: $query, prompt: Text("Notizen, Symptome, Medikamente …"))
      .task(id: query) {
        await runSearch()
      }
    }
  }

  private func runSearch() async {
    let text = query
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
      hits = []
      searchedQuery = text
      return
    }
    // Wait until typing pauses.
    try? await Task.sleep(for: .milliseconds(250))
    guard !Task.isCancelled else { return }
    isSearching = true
    defer { isSearching = false }
    let search = FullTextSearch(modelContainer: modelContext.container)
    let result = (try? await search.search(text, vocabulary: .app)) ?? []
    guard !Task.isCancelled else { return }
    hits = result
    searchedQuery = text
  }
}

extension SearchVocabulary {
  /// Localised names of the fixed choices, so "Husten" finds cough symptoms.
  static var app: SearchVocabulary {
    SearchVocabulary(
      symptomCategories: Dictionary(uniqueKeysWithValues: SymptomCategory.allCases.map { ($0.rawValue, $0.title) }),
      treatmentKinds: Dictionary(uniqueKeysWithValues: TreatmentKind.allCases.map { ($0.rawValue, $0.title) }),
      measurementTypes: Dictionary(uniqueKeysWithValues: MeasurementType.allCases.map { ($0.rawValue, $0.title) }),
      trainingTypes: Dictionary(uniqueKeysWithValues: TrainingType.allCases.map { ($0.rawValue, $0.title) }))
  }
}

extension SearchHitKind {
  var sectionTitle: LocalizedStringKey {
    switch self {
    case .symptom: "Symptome"
    case .condition: "Krankheiten"
    case .treatment: "Behandlungen"
    case .medication: "Medikamente"
    case .horse: "Pferde"
    case .measurement: "Messwerte"
    case .feeding: "Fütterung"
    case .training: "Training"
    }
  }

  var systemImage: String {
    switch self {
    case .symptom: "cross.case"
    case .condition: "heart.text.clipboard"
    case .treatment: "stethoscope"
    case .medication: "pills"
    case .horse: "figure.equestrian.sports"
    case .measurement: "chart.xyaxis.line"
    case .feeding: "leaf"
    case .training: "figure.equestrian.sports"
    }
  }

  var color: Color {
    switch self {
    case .symptom, .condition: .categorySymptoms
    case .treatment: .categoryTreatments
    case .medication: .categoryMedications
    case .horse: .accentColor
    case .measurement: .categoryMeasurements
    case .feeding: .categoryFeeding
    case .training: .categoryTraining
    }
  }
}

struct SearchHitRow: View {
  let hit: SearchHit

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: hit.kind.systemImage)
        .foregroundStyle(hit.kind.color)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(hit.title)
        let meta = [hit.horseName, hit.date?.formatted(date: .abbreviated, time: .omitted)].compactMap { $0 }
        if !meta.isEmpty {
          Text(meta.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
        }
        if let snippet = hit.snippet {
          Text(snippet).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// Opens the record of a hit; loads it by id from the main context.
struct SearchHitDestination: View {
  @Environment(\.modelContext) private var modelContext
  let hit: SearchHit

  var body: some View {
    switch hit.kind {
    case .symptom:
      if let symptom: SymptomEntry = fetch() { SymptomDetailView(symptom: symptom) } else { missing }
    case .condition:
      if let condition: Condition = fetch() { ConditionDetailView(condition: condition) } else { missing }
    case .treatment, .medication:
      if let treatment: Treatment = fetch() { TreatmentDetailView(treatment: treatment) } else { missing }
    case .horse:
      if let horse: Horse = fetch() { HorseProfileView(horse: horse) } else { missing }
    case .measurement:
      if let measurement: BodyMeasurement = fetch(), let horse = measurement.horse {
        MeasurementDetailView(horse: horse, type: measurement.type)
      } else {
        missing
      }
    case .feeding:
      if let log: FeedingLog = fetch(), let horse = log.horse {
        FeedingDayView(horse: horse, date: log.timestamp)
      } else {
        missing
      }
    case .training:
      if let session: TrainingSession = fetch() { TrainingDetailView(session: session) } else { missing }
    }
  }

  private var missing: some View {
    ContentUnavailableView("Eintrag nicht gefunden", systemImage: "questionmark.folder")
  }

  private func fetch<T: EquiRecord>() -> T? {
    let id = hit.recordID
    return try? modelContext.fetch(FetchDescriptor<T>(predicate: #Predicate { $0.id == id })).first
  }
}

#Preview {
  SearchView()
}

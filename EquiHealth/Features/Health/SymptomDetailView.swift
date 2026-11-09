import EquiCore
import SwiftData
import SwiftUI

/// Detail of one symptom (F-GESUND-01, F-GESUND-03).
// ANNAHME: Die Wetteranzeige am Tag des Beginns und den drei Tagen davor (F-GESUND-05) folgt in Phase 5.
struct SymptomDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var symptom: SymptomEntry
  @State private var showsEditor = false

  var body: some View {
    List {
      Section {
        HStack(spacing: 12) {
          Image(systemName: symptom.category.systemImage)
            .font(.title)
            .foregroundStyle(Color.categorySymptoms)
            .accessibilityHidden(true)
          VStack(alignment: .leading) {
            Text(symptom.categoryTitle).font(.title2.bold())
            Text("Schweregrad: \(symptom.severity.title)").foregroundStyle(.secondary)
          }
        }
        LabeledContent("Beginn", value: symptom.startDate.formatted(date: .long, time: .shortened))
        if let endDate = symptom.endDate {
          LabeledContent("Ende", value: endDate.formatted(date: .long, time: .shortened))
        } else {
          LabeledContent("Status", value: String(localized: "laufend"))
          Button("Symptom jetzt beenden", systemImage: "checkmark.circle") { endNow() }
        }
      }

      let lines = symptom.details.summaryLines
      if !lines.isEmpty {
        Section("Details") {
          ForEach(lines, id: \.self) { Text($0) }
        }
      }

      if symptom.condition != nil || symptom.treatment != nil {
        Section("Verknüpft mit") {
          if let condition = symptom.condition {
            NavigationLink {
              ConditionDetailView(condition: condition)
            } label: {
              Label(condition.name, systemImage: "heart.text.clipboard")
            }
          }
          if let treatment = symptom.treatment {
            NavigationLink {
              TreatmentDetailView(treatment: treatment)
            } label: {
              Label(
                "\(treatment.kindTitle), \(treatment.date.formatted(date: .abbreviated, time: .omitted))",
                systemImage: treatment.kind.systemImage)
            }
          }
        }
      }

      if let attachments = symptom.attachments, !attachments.isEmpty {
        Section("Fotos") {
          AttachmentGallery(attachments: attachments)
        }
      }

      if !symptom.note.isEmpty {
        Section("Notiz") { Text(symptom.note) }
      }
    }
    .navigationTitle(symptom.categoryTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Bearbeiten") { showsEditor = true }
      }
    }
    .sheet(isPresented: $showsEditor) {
      if let horse = symptom.horse {
        SymptomFormView(horse: horse, symptom: symptom)
      }
    }
  }

  private func endNow() {
    symptom.endDate = max(.now, symptom.startDate)
    symptom.touch()
    try? modelContext.save()
  }
}

/// Compact row for a symptom in lists and the timeline.
struct SymptomRow: View {
  let symptom: SymptomEntry

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: symptom.category.systemImage)
        .foregroundStyle(Color.categorySymptoms)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(symptom.categoryTitle)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var subtitle: String {
    let start = symptom.startDate.formatted(date: .abbreviated, time: .omitted)
    if let end = symptom.endDate {
      return String(
        localized: "\(symptom.severity.title) · \(start) – \(end.formatted(date: .abbreviated, time: .omitted))")
    }
    return String(localized: "\(symptom.severity.title) · seit \(start)")
  }
}

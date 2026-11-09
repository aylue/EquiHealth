import EquiCore
import SwiftData
import SwiftUI

/// Create or edit a disease or diagnosis (F-GESUND-04).
struct ConditionFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  let horse: Horse
  let condition: Condition?

  @State private var name: String
  @State private var hasDiagnosisDate: Bool
  @State private var diagnosedAt: Date
  @State private var isHealed: Bool
  @State private var healedAt: Date
  @State private var isChronic: Bool
  @State private var diagnosedBy: String
  @State private var note: String

  init(horse: Horse, condition: Condition? = nil) {
    self.horse = horse
    self.condition = condition
    _name = State(initialValue: condition?.name ?? "")
    _hasDiagnosisDate = State(initialValue: condition == nil || condition?.diagnosedAt != nil)
    _diagnosedAt = State(initialValue: condition?.diagnosedAt ?? .now)
    _isHealed = State(initialValue: condition?.healedAt != nil)
    _healedAt = State(initialValue: condition?.healedAt ?? .now)
    _isChronic = State(initialValue: condition?.isChronic ?? false)
    _diagnosedBy = State(initialValue: condition?.diagnosedBy ?? "")
    _note = State(initialValue: condition?.note ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Bezeichnung", text: $name)
            .accessibilityIdentifier("condition.name")
          Toggle("Chronisch", isOn: $isChronic)
        } footer: {
          Text("Chronische Erkrankungen werden im Pferdeprofil dauerhaft angezeigt.")
        }
        Section {
          Toggle("Diagnosedatum bekannt", isOn: $hasDiagnosisDate.animation())
          if hasDiagnosisDate {
            DatePicker("Diagnostiziert am", selection: $diagnosedAt, displayedComponents: .date)
          }
          TextField("Diagnostiziert von", text: $diagnosedBy)
          Toggle("Ausgeheilt", isOn: $isHealed.animation())
          if isHealed {
            DatePicker("Ausgeheilt am", selection: $healedAt, displayedComponents: .date)
          }
        }
        Section("Notiz") {
          TextField("Notiz", text: $note, axis: .vertical)
        }
      }
      .navigationTitle(condition == nil ? "Neue Krankheit" : "Krankheit bearbeiten")
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
    let target = condition ?? Condition(horse: horse, name: trimmed)
    if condition == nil { modelContext.insert(target) }
    target.name = trimmed
    target.diagnosedAt = hasDiagnosisDate ? diagnosedAt : nil
    target.healedAt = isHealed ? healedAt : nil
    target.isChronic = isChronic
    target.diagnosedBy = diagnosedBy.nilIfBlank
    target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    target.touch()
    try? modelContext.save()
    dismiss()
  }
}

/// Detail of a condition with linked symptoms and treatments (F-GESUND-04).
struct ConditionDetailView: View {
  @Bindable var condition: Condition
  @State private var showsEditor = false

  var body: some View {
    List {
      Section {
        if condition.isChronic {
          Label("Chronisch", systemImage: "infinity").foregroundStyle(Color.categorySymptoms)
        }
        if let diagnosedAt = condition.diagnosedAt {
          LabeledContent("Diagnostiziert am", value: diagnosedAt.formatted(date: .long, time: .omitted))
        }
        if let diagnosedBy = condition.diagnosedBy {
          LabeledContent("Diagnostiziert von", value: diagnosedBy)
        }
        LabeledContent(
          "Status",
          value: condition.healedAt.map {
            String(localized: "ausgeheilt am \($0.formatted(date: .abbreviated, time: .omitted))")
          } ?? String(localized: "aktiv"))
      }
      let symptoms = (condition.symptoms ?? []).sorted { $0.startDate > $1.startDate }
      if !symptoms.isEmpty {
        Section("Symptome") {
          ForEach(symptoms) { symptom in
            NavigationLink {
              SymptomDetailView(symptom: symptom)
            } label: {
              SymptomRow(symptom: symptom)
            }
          }
        }
      }
      let treatments = (condition.treatments ?? []).sorted { $0.date > $1.date }
      if !treatments.isEmpty {
        Section("Behandlungen") {
          ForEach(treatments) { treatment in
            NavigationLink {
              TreatmentDetailView(treatment: treatment)
            } label: {
              TreatmentRow(treatment: treatment)
            }
          }
        }
      }
      if !condition.note.isEmpty {
        Section("Notiz") { Text(condition.note) }
      }
    }
    .navigationTitle(condition.name)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Bearbeiten") { showsEditor = true }
      }
    }
    .sheet(isPresented: $showsEditor) {
      if let horse = condition.horse {
        ConditionFormView(horse: horse, condition: condition)
      }
    }
  }
}

/// Compact row for a condition.
struct ConditionRow: View {
  let condition: Condition

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: condition.isChronic ? "infinity" : "heart.text.clipboard")
        .foregroundStyle(Color.categorySymptoms)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(condition.name)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var subtitle: String {
    var parts: [String] = []
    if condition.isChronic { parts.append(String(localized: "chronisch")) }
    if let diagnosedAt = condition.diagnosedAt {
      parts.append(String(localized: "diagnostiziert \(diagnosedAt.formatted(date: .abbreviated, time: .omitted))"))
    }
    if condition.healedAt != nil { parts.append(String(localized: "ausgeheilt")) }
    return parts.joined(separator: " · ")
  }
}

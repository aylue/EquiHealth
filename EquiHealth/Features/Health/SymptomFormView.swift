import EquiCore
import SwiftData
import SwiftUI

/// Create or edit a symptom (F-GESUND-01, F-GESUND-02).
struct SymptomFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  let horse: Horse
  let symptom: SymptomEntry?

  @Query(filter: #Predicate<SymptomEntry> { $0.categoryRaw == "custom" }) private var customSymptoms: [SymptomEntry]

  @State private var category: SymptomCategory
  @State private var customCategoryName: String
  @State private var severity: Severity
  @State private var startDate: Date
  @State private var hasEnded: Bool
  @State private var endDate: Date
  @State private var details: SymptomDetails
  @State private var conditionID: UUID?
  @State private var treatmentID: UUID?
  @State private var note: String
  @State private var attachments: [AttachmentDraft]

  init(horse: Horse, symptom: SymptomEntry? = nil) {
    self.horse = horse
    self.symptom = symptom
    _category = State(initialValue: symptom?.category ?? .cough)
    _customCategoryName = State(initialValue: symptom?.customCategoryName ?? "")
    _severity = State(initialValue: symptom?.severity ?? .mild)
    _startDate = State(initialValue: symptom?.startDate ?? .now)
    _hasEnded = State(initialValue: symptom?.endDate != nil)
    _endDate = State(initialValue: symptom?.endDate ?? .now)
    _details = State(initialValue: symptom?.details ?? SymptomDetails())
    _conditionID = State(initialValue: symptom?.condition?.id)
    _treatmentID = State(initialValue: symptom?.treatment?.id)
    _note = State(initialValue: symptom?.note ?? "")
    _attachments = State(initialValue: (symptom?.attachments ?? []).compactMap(AttachmentDraft.init))
  }

  private var isValid: Bool {
    category != .custom || customCategoryName.nilIfBlank != nil
  }

  /// Names of user-defined categories used before (F-GESUND-02).
  private var knownCustomNames: [String] {
    Array(Set(customSymptoms.compactMap(\.customCategoryName))).sorted()
  }

  private var conditions: [Condition] {
    (horse.conditions ?? []).sorted { $0.name < $1.name }
  }

  private var treatments: [Treatment] {
    (horse.treatments ?? []).sorted { $0.date > $1.date }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Kategorie", selection: $category) {
            ForEach(SymptomCategory.allCases, id: \.self) { category in
              Label(category.title, systemImage: category.systemImage).tag(category)
            }
          }
          .accessibilityIdentifier("symptom.category")
          if category == .custom {
            TextField("Name der Kategorie", text: $customCategoryName)
            if !knownCustomNames.isEmpty {
              Menu("Bisherige Kategorien") {
                ForEach(knownCustomNames, id: \.self) { name in
                  Button(name) { customCategoryName = name }
                }
              }
            }
          }
          Picker("Schweregrad", selection: $severity) {
            ForEach(Severity.allCases, id: \.self) { severity in
              Text(severity.title).tag(severity)
            }
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("symptom.severity")
        }

        Section {
          DatePicker("Beginn", selection: $startDate)
          Toggle("Beendet", isOn: $hasEnded.animation())
          if hasEnded {
            DatePicker("Ende", selection: $endDate, in: startDate...)
          }
        } footer: {
          if !hasEnded {
            Text("Laufende Symptome erscheinen oben in der Übersicht.")
          }
        }

        SymptomDetailsEditor(category: category, details: $details)

        Section("Verknüpfungen") {
          Picker("Krankheit", selection: $conditionID) {
            Text("Keine").tag(UUID?.none)
            ForEach(conditions) { condition in
              Text(condition.name).tag(Optional(condition.id))
            }
          }
          Picker("Behandlung", selection: $treatmentID) {
            Text("Keine").tag(UUID?.none)
            ForEach(treatments) { treatment in
              Text("\(treatment.kindTitle), \(treatment.date.formatted(date: .abbreviated, time: .omitted))")
                .tag(Optional(treatment.id))
            }
          }
          .accessibilityIdentifier("symptom.treatment")
        }

        AttachmentEditorSection(drafts: $attachments)

        Section("Notiz") {
          TextField("Notiz", text: $note, axis: .vertical)
            .lineLimit(2...)
        }
      }
      .navigationTitle(symptom == nil ? "Symptom erfassen" : "Symptom bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(!isValid)
            .accessibilityIdentifier("save")
        }
      }
    }
  }

  private func save() {
    let target: SymptomEntry
    if let symptom {
      target = symptom
    } else {
      target = SymptomEntry(horse: horse, category: category, severity: severity, startDate: startDate)
      modelContext.insert(target)
    }
    target.category = category
    target.customCategoryName = category == .custom ? customCategoryName.nilIfBlank : nil
    target.severity = severity
    target.startDate = startDate
    target.endDate = hasEnded ? max(endDate, startDate) : nil
    target.details = details.restricted(to: category)
    target.condition = conditions.first { $0.id == conditionID }
    target.treatment = treatments.first { $0.id == treatmentID }
    target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    AttachmentDraft.apply(attachments, existing: target.attachments ?? [], in: modelContext) {
      $0.symptom = target
    }
    target.touch()
    try? modelContext.save()
    dismiss()
  }
}

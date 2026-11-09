import EquiCore
import SwiftData
import SwiftUI

/// Create or edit a treatment with medications and attachments (F-BEH-01 to F-BEH-05, F-BEH-07).
struct TreatmentFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  let horse: Horse
  let treatment: Treatment?

  @Query(sort: \Contact.name) private var contacts: [Contact]

  @State private var kind: TreatmentKind
  @State private var customKindName: String
  @State private var date: Date
  @State private var contactID: UUID?
  @State private var descriptionText: String
  @State private var costText: String
  @State private var conditionID: UUID?
  @State private var medications: [MedicationDraft]
  @State private var attachments: [AttachmentDraft]
  @State private var editingMedication: MedicationDraft?
  @State private var showsNewContact = false

  init(horse: Horse, treatment: Treatment? = nil, kind: TreatmentKind = .veterinarian) {
    self.horse = horse
    self.treatment = treatment
    _kind = State(initialValue: treatment?.kind ?? kind)
    _customKindName = State(initialValue: treatment?.customKindName ?? "")
    _date = State(initialValue: treatment?.date ?? .now)
    _contactID = State(initialValue: treatment?.contact?.id)
    _descriptionText = State(initialValue: treatment?.descriptionText ?? "")
    _costText = State(initialValue: treatment?.cost.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "")
    _conditionID = State(initialValue: treatment?.condition?.id)
    _medications = State(
      initialValue: (treatment?.medications ?? []).sorted { $0.createdAt < $1.createdAt }.map(MedicationDraft.init))
    _attachments = State(initialValue: (treatment?.attachments ?? []).compactMap(AttachmentDraft.init))
  }

  private var conditions: [Condition] {
    (horse.conditions ?? []).sorted { $0.name < $1.name }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Art", selection: $kind) {
            ForEach(TreatmentKind.allCases, id: \.self) { kind in
              Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
          }
          .accessibilityIdentifier("treatment.kind")
          if kind == .other {
            TextField("Bezeichnung", text: $customKindName)
          }
          DatePicker("Datum", selection: $date)
          Picker("Dienstleister", selection: $contactID) {
            Text("Keiner").tag(UUID?.none)
            ForEach(contacts) { contact in
              Text(contact.name).tag(Optional(contact.id))
            }
          }
          .accessibilityIdentifier("treatment.contact")
          Button("Neuen Kontakt anlegen", systemImage: "person.badge.plus") { showsNewContact = true }
            .accessibilityIdentifier("treatment.newContact")
        }

        Section("Beschreibung") {
          TextField("Was wurde gemacht?", text: $descriptionText, axis: .vertical)
            .lineLimit(2...)
            .accessibilityIdentifier("treatment.description")
        }

        Section(kind == .vaccination ? "Impfstoffe" : "Medikamente") {
          ForEach(medications) { draft in
            Button {
              editingMedication = draft
            } label: {
              VStack(alignment: .leading) {
                Text(draft.productName).foregroundStyle(.primary)
                ForEach(WithdrawalKind.allCases, id: \.self) { withdrawal in
                  if let end = draft.withdrawalEnd(withdrawal, treatmentDate: date) {
                    Text("\(withdrawal.title) bis \(end.formatted(date: .abbreviated, time: .omitted))")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
          }
          .onDelete { medications.remove(atOffsets: $0) }
          Button(kind == .vaccination ? "Impfstoff hinzufügen" : "Medikament hinzufügen", systemImage: "plus") {
            editingMedication = MedicationDraft()
          }
          .accessibilityIdentifier("treatment.addMedication")
        }

        Section {
          Picker("Krankheit", selection: $conditionID) {
            Text("Keine").tag(UUID?.none)
            ForEach(conditions) { condition in
              Text(condition.name).tag(Optional(condition.id))
            }
          }
          LabeledContent("Kosten") {
            HStack {
              TextField("0,00", text: $costText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(Text("Kosten"))
              Text(Locale.current.currency?.identifier ?? "EUR").foregroundStyle(.secondary)
            }
          }
        }

        AttachmentEditorSection(drafts: $attachments, allowsDocuments: true)
      }
      .navigationTitle(treatment == nil ? "Behandlung erfassen" : "Behandlung bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(kind == .other && customKindName.nilIfBlank == nil)
            .accessibilityIdentifier("save")
        }
      }
      .sheet(item: $editingMedication) { draft in
        MedicationFormView(draft: draft, isVaccination: kind == .vaccination, treatmentDate: date) { saved in
          if let index = medications.firstIndex(where: { $0.id == saved.id }) {
            medications[index] = saved
          } else {
            medications.append(saved)
          }
        }
      }
      .sheet(isPresented: $showsNewContact) {
        ContactFormView(contact: nil, role: kind.suggestedContactRole) { contactID = $0.id }
      }
    }
  }

  private func save() {
    let target = treatment ?? Treatment(horse: horse, kind: kind, date: date)
    if treatment == nil { modelContext.insert(target) }
    target.kind = kind
    target.customKindName = kind == .other ? customKindName.nilIfBlank : nil
    target.date = date
    target.contact = contacts.first { $0.id == contactID }
    target.descriptionText = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
    target.cost = DecimalInput.parse(costText)
    target.currencyCode = target.cost == nil ? nil : (Locale.current.currency?.identifier ?? "EUR")
    target.condition = conditions.first { $0.id == conditionID }

    let existing = target.medications ?? []
    let keptIDs = Set(medications.compactMap(\.existingID))
    for medication in existing where !keptIDs.contains(medication.id) {
      modelContext.delete(medication)
    }
    for draft in medications {
      let medication: Medication
      if let existingID = draft.existingID, let match = existing.first(where: { $0.id == existingID }) {
        medication = match
      } else {
        medication = Medication(treatment: target, productName: draft.productName)
        modelContext.insert(medication)
      }
      draft.apply(to: medication, isVaccination: kind == .vaccination)
    }

    AttachmentDraft.apply(attachments, existing: target.attachments ?? [], in: modelContext) {
      $0.treatment = target
    }
    target.touch()
    try? modelContext.save()
    dismiss()
  }
}

extension TreatmentKind {
  /// Contact role preselected when creating a contact from a treatment.
  var suggestedContactRole: ContactRole {
    switch self {
    case .veterinarian, .vaccination, .deworming: .veterinarian
    case .dental: .dentist
    case .farrier: .farrier
    case .osteopathy: .osteopath
    case .physiotherapy: .physiotherapist
    case .other: .other
    }
  }
}

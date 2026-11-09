import EquiCore
import SwiftData
import SwiftUI

/// Detail of a treatment (F-BEH-01, F-BEH-03, F-BEH-05, F-BEH-08).
struct TreatmentDetailView: View {
  @Bindable var treatment: Treatment
  @State private var showsEditor = false

  var body: some View {
    List {
      Section {
        HStack(spacing: 12) {
          Image(systemName: treatment.kind.systemImage)
            .font(.title)
            .foregroundStyle(Color.categoryTreatments)
            .accessibilityHidden(true)
          VStack(alignment: .leading) {
            Text(treatment.kindTitle).font(.title2.bold())
            Text(treatment.date.formatted(date: .long, time: .shortened)).foregroundStyle(.secondary)
          }
        }
        if !treatment.descriptionText.isEmpty {
          Text(treatment.descriptionText)
        }
        if let cost = treatment.cost {
          LabeledContent(
            "Kosten", value: cost.formatted(.currency(code: treatment.currencyCode ?? "EUR")))
        }
      }

      if let contact = treatment.contact {
        Section("Dienstleister") {
          ContactSummary(contact: contact)
        }
      }

      let medications = (treatment.medications ?? []).sorted { $0.createdAt < $1.createdAt }
      if !medications.isEmpty {
        Section(treatment.kind == .vaccination ? "Impfstoffe" : "Medikamente") {
          ForEach(medications) { medication in
            MedicationRow(medication: medication)
          }
        }
      }

      let rules = (treatment.horse?.reminderRules ?? []).filter { $0.isFulfilled(by: treatment) }
      if !rules.isEmpty {
        Section {
          ForEach(rules) { rule in
            ReminderRow(rule: rule, showsHorse: false)
          }
        } header: {
          Text("Erinnerungen")
        } footer: {
          Text("Die nächste Fälligkeit wird aus der letzten passenden Behandlung berechnet.")
        }
      }

      let symptoms = (treatment.symptoms ?? []).sorted { $0.startDate > $1.startDate }
      if treatment.condition != nil || !symptoms.isEmpty {
        Section("Verknüpft mit") {
          if let condition = treatment.condition {
            NavigationLink {
              ConditionDetailView(condition: condition)
            } label: {
              ConditionRow(condition: condition)
            }
          }
          ForEach(symptoms) { symptom in
            NavigationLink {
              SymptomDetailView(symptom: symptom)
            } label: {
              SymptomRow(symptom: symptom)
            }
          }
        }
      }

      if let attachments = treatment.attachments, !attachments.isEmpty {
        Section("Anhänge") {
          AttachmentGallery(attachments: attachments)
        }
      }
    }
    .navigationTitle(treatment.kindTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Bearbeiten") { showsEditor = true }
      }
    }
    .sheet(isPresented: $showsEditor) {
      if let horse = treatment.horse {
        TreatmentFormView(horse: horse, treatment: treatment)
      }
    }
  }
}

/// Compact row for a treatment.
struct TreatmentRow: View {
  let treatment: Treatment

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: treatment.kind.systemImage)
        .foregroundStyle(Color.categoryTreatments)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(treatment.kindTitle)
        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var subtitle: String {
    var parts = [treatment.date.formatted(date: .abbreviated, time: .omitted)]
    if let contact = treatment.contact { parts.append(contact.name) }
    let medications = (treatment.medications ?? []).map(\.productName)
    if !medications.isEmpty { parts.append(medications.formatted(.list(type: .and))) }
    return parts.joined(separator: " · ")
  }
}

/// "Behandlungen" of one horse, with access to the vaccination overview (F-BEH-04).
struct TreatmentsListView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AppState.self) private var appState
  let horse: Horse

  var body: some View {
    let treatments = (horse.treatments ?? []).sorted { $0.date > $1.date }
    List {
      Section {
        NavigationLink {
          VaccinationOverviewView(horse: horse)
        } label: {
          Label("Impfübersicht", systemImage: "syringe")
        }
      }
      if treatments.isEmpty {
        ContentUnavailableView {
          Label("Keine Behandlungen", systemImage: "stethoscope")
        } actions: {
          Button("Behandlung erfassen") { appState.sheet = .newTreatment }
            .buttonStyle(.borderedProminent)
        }
      } else {
        Section("Alle Behandlungen") {
          ForEach(treatments) { treatment in
            NavigationLink {
              TreatmentDetailView(treatment: treatment)
            } label: {
              TreatmentRow(treatment: treatment)
            }
          }
          .onDelete { offsets in
            for index in offsets { modelContext.delete(treatments[index]) }
            try? modelContext.save()
          }
        }
      }
    }
    .navigationTitle("Behandlungen")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Behandlung hinzufügen", systemImage: "plus") { appState.sheet = .newTreatment }
      }
    }
  }
}

/// Last vaccination and next due date per disease (F-BEH-04).
struct VaccinationOverviewView: View {
  @Environment(AppState.self) private var appState
  let horse: Horse

  var body: some View {
    let last = horse.lastVaccinations()
    let rules = (horse.reminderRules ?? []).filter { $0.isActive && $0.matchingVaccinationTarget != nil }
    List {
      Section {
        ForEach(VaccinationTarget.allCases.filter { $0 != .other }, id: \.self) { target in
          let next = rules.filter { $0.matchingVaccinationTarget == target }.compactMap { $0.nextDueDate() }.min()
          VStack(alignment: .leading, spacing: 4) {
            Text(target.title).font(.headline)
            LabeledContent("Letzte Impfung") {
              Text(last[target].map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "–")
            }
            LabeledContent("Nächste Fälligkeit") {
              if let next {
                Text(next.formatted(date: .abbreviated, time: .omitted))
                  .foregroundStyle(next < Calendar.current.startOfDay(for: .now) ? Color.red : Color.primary)
              } else {
                Text("keine Erinnerung")
              }
            }
          }
          .accessibilityElement(children: .combine)
        }
      } footer: {
        Text("Die nächste Fälligkeit stammt aus deinen Erinnerungen unter „Termine“.")
      }
      Section {
        Button("Impf-Erinnerung anlegen", systemImage: "bell.badge") { appState.sheet = .newReminder }
      }
    }
    .navigationTitle("Impfübersicht")
  }
}

/// All medications of one horse, running withdrawal periods first.
struct MedicationsListView: View {
  let horse: Horse

  var body: some View {
    let medications = (horse.treatments ?? [])
      .flatMap { $0.medications ?? [] }
      .sorted { ($0.lastDoseDate ?? .distantPast) > ($1.lastDoseDate ?? .distantPast) }
    List {
      if !horse.activeWithdrawals().isEmpty {
        Section("Laufende Warte- und Karenzzeiten") {
          WithdrawalNoticeRows(horse: horse)
        }
      }
      if medications.isEmpty {
        ContentUnavailableView(
          "Keine Medikamente", systemImage: "pills",
          description: Text("Medikamente erfasst du innerhalb einer Behandlung."))
      } else {
        Section("Alle Medikamente") {
          ForEach(medications) { medication in
            if let treatment = medication.treatment {
              NavigationLink {
                TreatmentDetailView(treatment: treatment)
              } label: {
                MedicationRow(medication: medication)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Medikamente")
  }
}

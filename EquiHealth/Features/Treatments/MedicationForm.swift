import EquiCore
import SwiftData
import SwiftUI

/// How a withdrawal period is entered (F-BEH-08).
enum WithdrawalInputMode: String, CaseIterable, Identifiable {
  case none, days, date
  var id: String { rawValue }

  var title: String {
    switch self {
    case .none: String(localized: "Keine")
    case .days: String(localized: "Tage ab letzter Gabe")
    case .date: String(localized: "Datum")
    }
  }
}

/// Editable copy of a medication used inside the treatment form.
struct MedicationDraft: Identifiable, Equatable {
  var id = UUID()
  var existingID: UUID?
  var productName = ""
  var activeIngredient = ""
  var doseText = ""
  var doseUnit = ""
  var route: AdministrationRoute?
  var hasStart = false
  var startDate = Date.now
  var hasEnd = false
  var endDate = Date.now
  var frequency = ""
  var batchNumber = ""
  var vaccinationTargets: [VaccinationTarget] = []
  var customVaccinationTarget = ""
  var foodMode = WithdrawalInputMode.none
  var foodDaysText = ""
  var foodDate = Date.now
  var competitionMode = WithdrawalInputMode.none
  var competitionDaysText = ""
  var competitionDate = Date.now

  init() {}

  init(_ medication: Medication) {
    id = medication.id
    existingID = medication.id
    productName = medication.productName
    activeIngredient = medication.activeIngredient ?? ""
    doseText = medication.dose.map { $0.formatted(.number.grouping(.never)) } ?? ""
    doseUnit = medication.doseUnit ?? ""
    route = medication.route
    hasStart = medication.startDate != nil
    startDate = medication.startDate ?? .now
    hasEnd = medication.endDate != nil
    endDate = medication.endDate ?? .now
    frequency = medication.frequency ?? ""
    batchNumber = medication.batchNumber ?? ""
    vaccinationTargets = medication.vaccinationTargets
    customVaccinationTarget = medication.customVaccinationTarget ?? ""
    (foodMode, foodDaysText, foodDate) = Self.mode(
      until: medication.foodWithdrawalUntil, days: medication.foodWithdrawalDays)
    (competitionMode, competitionDaysText, competitionDate) = Self.mode(
      until: medication.competitionWithdrawalUntil, days: medication.competitionWithdrawalDays)
  }

  private static func mode(until: Date?, days: Int?) -> (WithdrawalInputMode, String, Date) {
    if let until { return (.date, "", until) }
    if let days { return (.days, String(days), .now) }
    return (.none, "", .now)
  }

  var isValid: Bool { productName.nilIfBlank != nil }

  private func days(_ text: String) -> Int? {
    DecimalInput.parse(text).map { Int($0.rounded()) }.flatMap { $0 >= 0 ? $0 : nil }
  }

  /// Last dose as the model would compute it (F-BEH-08).
  func lastDose(treatmentDate: Date) -> Date {
    hasEnd ? endDate : (hasStart ? startDate : treatmentDate)
  }

  /// Preview of the computed end date.
  func withdrawalEnd(_ kind: WithdrawalKind, treatmentDate: Date) -> Date? {
    let (mode, daysText, date) =
      kind == .food ? (foodMode, foodDaysText, foodDate) : (competitionMode, competitionDaysText, competitionDate)
    switch mode {
    case .none: return nil
    case .date: return WithdrawalCalculator.endDate(until: date, days: nil, lastDose: nil)
    case .days:
      return WithdrawalCalculator.endDate(
        until: nil, days: days(daysText), lastDose: lastDose(treatmentDate: treatmentDate))
    }
  }

  /// Writes the draft into `medication`.
  func apply(to medication: Medication, isVaccination: Bool) {
    medication.productName = productName.trimmingCharacters(in: .whitespacesAndNewlines)
    medication.activeIngredient = activeIngredient.nilIfBlank
    medication.dose = DecimalInput.parse(doseText)
    medication.doseUnit = doseUnit.nilIfBlank
    medication.route = route
    medication.startDate = hasStart ? startDate : nil
    medication.endDate = hasEnd ? endDate : nil
    medication.frequency = frequency.nilIfBlank
    medication.batchNumber = batchNumber.nilIfBlank
    medication.vaccinationTargets = isVaccination ? vaccinationTargets : []
    medication.customVaccinationTarget =
      isVaccination && vaccinationTargets.contains(.other) ? customVaccinationTarget.nilIfBlank : nil
    medication.foodWithdrawalUntil = foodMode == .date ? foodDate : nil
    medication.foodWithdrawalDays = foodMode == .days ? days(foodDaysText) : nil
    medication.competitionWithdrawalUntil = competitionMode == .date ? competitionDate : nil
    medication.competitionWithdrawalDays = competitionMode == .days ? days(competitionDaysText) : nil
    medication.touch()
  }
}

/// Edit one medication or vaccine (F-BEH-03, F-BEH-04, F-BEH-08).
struct MedicationFormView: View {
  @Environment(\.dismiss) private var dismiss
  @State var draft: MedicationDraft
  let isVaccination: Bool
  let treatmentDate: Date
  let onSave: (MedicationDraft) -> Void

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(isVaccination ? "Impfstoff" : "Präparat", text: $draft.productName)
            .accessibilityIdentifier("medication.product")
          TextField("Wirkstoff", text: $draft.activeIngredient)
          HStack {
            TextField("Dosis", text: $draft.doseText)
              .keyboardType(.decimalPad)
            TextField("Einheit, z. B. ml", text: $draft.doseUnit)
          }
          Picker("Verabreichung", selection: $draft.route) {
            Text("Keine Angabe").tag(AdministrationRoute?.none)
            ForEach(AdministrationRoute.allCases, id: \.self) { route in
              Text(route.title).tag(Optional(route))
            }
          }
          TextField("Häufigkeit, z. B. 2× täglich", text: $draft.frequency)
          TextField("Chargennummer", text: $draft.batchNumber)
        }

        if isVaccination {
          Section("Impfung gegen") {
            ForEach(VaccinationTarget.allCases, id: \.self) { target in
              Toggle(target.title, isOn: targetBinding(target))
            }
            if draft.vaccinationTargets.contains(.other) {
              TextField("Krankheit", text: $draft.customVaccinationTarget)
            }
          }
        }

        Section("Zeitraum") {
          Toggle("Beginn", isOn: $draft.hasStart.animation())
          if draft.hasStart {
            DatePicker("Beginn", selection: $draft.startDate, displayedComponents: .date)
          }
          Toggle("Ende (letzte Gabe)", isOn: $draft.hasEnd.animation())
          if draft.hasEnd {
            DatePicker("Ende", selection: $draft.endDate, displayedComponents: .date)
          }
        }

        withdrawalSection(
          .food, mode: $draft.foodMode, days: $draft.foodDaysText, date: $draft.foodDate,
          identifier: "medication.foodDays")
        withdrawalSection(
          .competition, mode: $draft.competitionMode, days: $draft.competitionDaysText,
          date: $draft.competitionDate, identifier: "medication.competitionDays")
      }
      .navigationTitle(isVaccination ? "Impfstoff" : "Medikament")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Übernehmen") {
            onSave(draft)
            dismiss()
          }
          .disabled(!draft.isValid)
          .accessibilityIdentifier("medication.save")
        }
      }
    }
  }

  private func targetBinding(_ target: VaccinationTarget) -> Binding<Bool> {
    Binding(
      get: { draft.vaccinationTargets.contains(target) },
      set: { isOn in
        if isOn {
          draft.vaccinationTargets = VaccinationTarget.allCases.filter {
            $0 == target || draft.vaccinationTargets.contains($0)
          }
        } else {
          draft.vaccinationTargets.removeAll { $0 == target }
        }
      })
  }

  private func withdrawalSection(
    _ kind: WithdrawalKind, mode: Binding<WithdrawalInputMode>, days: Binding<String>, date: Binding<Date>,
    identifier: String
  ) -> some View {
    Section {
      Picker("Angabe", selection: mode.animation()) {
        ForEach(WithdrawalInputMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      switch mode.wrappedValue {
      case .none:
        EmptyView()
      case .days:
        LabeledContent("Tage") {
          TextField("0", text: days)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(Text("\(kind.title) in Tagen"))
            .accessibilityIdentifier(identifier)
        }
      case .date:
        DatePicker("Bis", selection: date, displayedComponents: .date)
      }
      if let end = draft.withdrawalEnd(kind, treatmentDate: treatmentDate) {
        LabeledContent("Endet am", value: end.formatted(date: .long, time: .omitted))
      }
    } header: {
      Text(kind.title)
    } footer: {
      if kind == .food {
        Text("Werte aus Beipackzettel oder Tierarztangabe. Die App liefert keine eigenen Werte.")
      }
    }
  }
}

/// Row showing a medication with its withdrawal end dates.
struct MedicationRow: View {
  let medication: Medication

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Image(systemName: "pills")
          .foregroundStyle(Color.categoryMedications)
          .accessibilityHidden(true)
        Text(medication.productName)
      }
      let details = [
        medication.activeIngredient,
        medication.dose.map { dose in
          "\(dose.formatted()) \(medication.doseUnit ?? "")".trimmingCharacters(in: .whitespaces)
        },
        medication.route?.title,
        medication.frequency,
      ].compactMap { $0 }
      if !details.isEmpty {
        Text(details.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
      }
      if !medication.vaccinationTargets.isEmpty {
        Text(
          "gegen \(medication.vaccinationTargets.map(\.title).formatted(.list(type: .and)))"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      ForEach(WithdrawalKind.allCases, id: \.self) { kind in
        if let end = medication.withdrawalEnd(kind) {
          Text("\(kind.title) bis \(end.formatted(date: .abbreviated, time: .omitted))")
            .font(.caption)
            .foregroundStyle(WithdrawalCalculator.isRunning(end: end) ? .primary : .secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

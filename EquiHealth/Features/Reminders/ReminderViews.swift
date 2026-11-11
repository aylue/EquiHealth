import EquiCore
import SwiftData
import SwiftUI

/// Start values offered when creating a rule (F-ERIN-03). Only starting points that the user adjusts.
// ANNAHME: Intervalle nur dort vorbelegt, wo SPEC Beispiele nennt (Influenza 6 Monate, Zahnkontrolle
// 12 Monate, Hufschmied 6 Wochen). Für Tetanus, Herpes und Wurmkur gibt die App keinen Wert vor;
// das Intervall trägt der Nutzer ein. Siehe OPEN_QUESTIONS.md (Q-037).
struct ReminderTemplate: Identifiable {
  let kind: ReminderKind
  let title: String
  let intervalValue: Int?
  let intervalUnit: IntervalUnit
  let leadTimeDays: Int

  var id: String { kind.rawValue }

  static let all: [ReminderTemplate] = [
    ReminderTemplate(
      kind: .vaccinationInfluenza, title: String(localized: "Impfung Influenza"), intervalValue: 6,
      intervalUnit: .months, leadTimeDays: 14),
    ReminderTemplate(
      kind: .vaccinationTetanus, title: String(localized: "Impfung Tetanus"), intervalValue: nil,
      intervalUnit: .years, leadTimeDays: 14),
    ReminderTemplate(
      kind: .vaccinationHerpes, title: String(localized: "Impfung Herpes"), intervalValue: nil,
      intervalUnit: .months, leadTimeDays: 14),
    ReminderTemplate(
      kind: .dentalCheck, title: String(localized: "Zahnkontrolle"), intervalValue: 12, intervalUnit: .months,
      leadTimeDays: 14),
    ReminderTemplate(
      kind: .farrier, title: String(localized: "Hufschmied"), intervalValue: 6, intervalUnit: .weeks,
      leadTimeDays: 3),
    ReminderTemplate(
      kind: .deworming, title: String(localized: "Wurmkur"), intervalValue: nil, intervalUnit: .months,
      leadTimeDays: 7),
  ]
}

extension ReminderKind {
  nonisolated var title: String {
    switch self {
    case .vaccinationInfluenza: String(localized: "Impfung Influenza")
    case .vaccinationTetanus: String(localized: "Impfung Tetanus")
    case .vaccinationHerpes: String(localized: "Impfung Herpes")
    case .dentalCheck: String(localized: "Zahnkontrolle")
    case .farrier: String(localized: "Hufschmied")
    case .deworming: String(localized: "Wurmkur")
    case .custom: String(localized: "Eigene")
    }
  }

  nonisolated var systemImage: String {
    switch self {
    case .vaccinationInfluenza, .vaccinationTetanus, .vaccinationHerpes: "syringe"
    case .dentalCheck: "mouth"
    case .farrier: "hammer"
    case .deworming: "pills"
    case .custom: "bell"
    }
  }
}

extension IntervalUnit {
  nonisolated var title: String {
    switch self {
    case .days: String(localized: "Tage")
    case .weeks: String(localized: "Wochen")
    case .months: String(localized: "Monate")
    case .years: String(localized: "Jahre")
    }
  }
}

extension ReminderRule {
  /// "alle 6 Monate"
  var intervalDescription: String {
    String(localized: "alle \(intervalValue) \(intervalUnit.title)")
  }
}

/// Loads a rule by id for app-wide sheets.
struct ReminderRuleLoader<Content: View>: View {
  @Query private var rules: [ReminderRule]
  @ViewBuilder let content: (ReminderRule) -> Content

  init(id: UUID, @ViewBuilder content: @escaping (ReminderRule) -> Content) {
    _rules = Query(filter: #Predicate<ReminderRule> { $0.id == id })
    self.content = content
  }

  var body: some View {
    if let rule = rules.first {
      content(rule)
    } else {
      ContentUnavailableView("Erinnerung nicht gefunden", systemImage: "bell.slash")
    }
  }
}

/// Create or edit a reminder rule (F-ERIN-01 to F-ERIN-03).
struct ReminderRuleFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var appState

  let rule: ReminderRule?

  @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.sortIndex) private var horses: [Horse]
  @State private var horseID: UUID?
  @State private var kind: ReminderKind
  @State private var title: String
  @State private var customTreatmentKind: TreatmentKind
  @State private var intervalText: String
  @State private var intervalUnit: IntervalUnit
  @State private var leadTimeDays: Int
  @State private var reminderTime: Date
  @State private var hasStartDate: Bool
  @State private var startDate: Date
  @State private var isActive: Bool
  @State private var showsDeleteConfirmation = false

  init(rule: ReminderRule?) {
    self.rule = rule
    _horseID = State(initialValue: rule?.horse?.id)
    _kind = State(initialValue: rule?.kind ?? .custom)
    _title = State(initialValue: rule?.title ?? "")
    _customTreatmentKind = State(initialValue: rule?.matchingTreatmentKind ?? .other)
    _intervalText = State(initialValue: rule.map { String($0.intervalValue) } ?? "")
    _intervalUnit = State(initialValue: rule?.intervalUnit ?? .months)
    _leadTimeDays = State(initialValue: rule?.leadTimeDays ?? 7)
    let time =
      Calendar.current.date(
        bySettingHour: rule?.reminderHour ?? 9, minute: rule?.reminderMinute ?? 0, second: 0, of: .now) ?? .now
    _reminderTime = State(initialValue: time)
    _hasStartDate = State(initialValue: rule?.startDate != nil)
    _startDate = State(initialValue: rule?.startDate ?? .now)
    _isActive = State(initialValue: rule?.isActive ?? true)
  }

  private var intervalValue: Int? {
    Int(intervalText.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
  }

  private var isValid: Bool {
    title.nilIfBlank != nil && intervalValue != nil && horses.contains { $0.id == horseID }
  }

  var body: some View {
    NavigationStack {
      Form {
        if rule == nil {
          Section {
            ForEach(ReminderTemplate.all) { template in
              Button {
                apply(template)
              } label: {
                HStack {
                  Label(template.title, systemImage: template.kind.systemImage)
                  Spacer()
                  if kind == template.kind {
                    Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityLabel("ausgewählt")
                  }
                }
              }
              .foregroundStyle(.primary)
              .accessibilityIdentifier("reminder.template.\(template.kind.rawValue)")
            }
          } header: {
            Text("Vorlage")
          } footer: {
            Text("Vorlagen enthalten nur Startwerte. Passe Intervall und Vorlauf an dein Pferd an.")
          }
        }

        Section {
          Picker("Pferd", selection: $horseID) {
            ForEach(horses) { horse in
              Text(horse.name).tag(Optional(horse.id))
            }
          }
          TextField("Titel", text: $title)
            .accessibilityIdentifier("reminder.title")
          Picker("Art", selection: $kind) {
            ForEach(ReminderKind.allCases, id: \.self) { kind in
              Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
          }
          if kind == .custom {
            Picker("Erledigt durch", selection: $customTreatmentKind) {
              ForEach(TreatmentKind.allCases, id: \.self) { kind in
                Text(kind.title).tag(kind)
              }
            }
          }
        } footer: {
          if let matching = matching {
            Text(
              "Die nächste Fälligkeit rechnet ab der letzten Behandlung „\(matching.kind.title)“\(matching.target.map { String(localized: " gegen \($0.title)") } ?? "")."
            )
          }
        }

        Section("Intervall") {
          HStack {
            Text("alle")
            TextField("Anzahl", text: $intervalText)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.trailing)
              .accessibilityLabel(Text("Intervall"))
              .accessibilityIdentifier("reminder.interval")
            Picker("Einheit", selection: $intervalUnit) {
              ForEach(IntervalUnit.allCases, id: \.self) { unit in
                Text(unit.title).tag(unit)
              }
            }
            .labelsHidden()
            .accessibilityIdentifier("reminder.intervalUnit")
          }
        }

        Section {
          Stepper(value: $leadTimeDays, in: 0...90) {
            LabeledContent("Vorlaufzeit", value: String(localized: "\(leadTimeDays) Tage"))
          }
          .accessibilityIdentifier("reminder.leadTime")
          DatePicker("Uhrzeit", selection: $reminderTime, displayedComponents: .hourAndMinute)
        } header: {
          Text("Erinnerung")
        } footer: {
          Text("Du wirst um diese Uhrzeit am Fälligkeitstag erinnert und, falls gewählt, so viele Tage vorher.")
        }

        Section {
          Toggle("Erster Termin", isOn: $hasStartDate.animation())
          if hasStartDate {
            DatePicker("Datum", selection: $startDate, displayedComponents: .date)
          }
          Toggle("Aktiv", isOn: $isActive)
        } footer: {
          Text("Der erste Termin gilt, solange noch keine passende Behandlung erfasst ist.")
        }

        if let rule, let due = rule.nextDueDate() {
          Section {
            LabeledContent("Nächste Fälligkeit", value: due.formatted(date: .long, time: .omitted))
          }
        }

        if rule != nil {
          Section {
            Button("Erinnerung löschen", role: .destructive) { showsDeleteConfirmation = true }
          }
        }
      }
      .navigationTitle(rule == nil ? "Neue Erinnerung" : "Erinnerung bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(!isValid)
            .accessibilityIdentifier("reminder.save")
        }
      }
      .confirmationDialog("Erinnerung löschen?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
        Button("Löschen", role: .destructive) {
          if let rule { modelContext.delete(rule) }
          try? modelContext.save()
          dismiss()
        }
      }
      .onAppear {
        if horseID == nil {
          horseID = ActiveHorseSelection.resolve(storedID: appState.activeHorseID, in: horses)?.id
        }
      }
    }
  }

  private var matching: (kind: TreatmentKind, target: VaccinationTarget?)? {
    kind == .custom ? (customTreatmentKind, nil) : kind.defaultMatching
  }

  private func apply(_ template: ReminderTemplate) {
    kind = template.kind
    title = template.title
    intervalText = template.intervalValue.map(String.init) ?? ""
    intervalUnit = template.intervalUnit
    leadTimeDays = template.leadTimeDays
  }

  private func save() {
    guard let intervalValue, let horse = horses.first(where: { $0.id == horseID }), let name = title.nilIfBlank else {
      return
    }
    let target =
      rule
      ?? ReminderRule(horse: horse, kind: kind, title: name, intervalValue: intervalValue, intervalUnit: intervalUnit)
    if rule == nil { modelContext.insert(target) }
    target.horse = horse
    target.kind = kind
    target.title = name
    target.intervalValue = intervalValue
    target.intervalUnit = intervalUnit
    target.leadTimeDays = leadTimeDays
    let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
    target.reminderHour = time.hour ?? 9
    target.reminderMinute = time.minute ?? 0
    target.startDate = hasStartDate ? Calendar.current.startOfDay(for: startDate) : nil
    target.isActive = isActive
    target.matchingTreatmentKind = matching?.kind
    target.matchingVaccinationTarget = matching?.target
    target.touch()
    try? modelContext.save()
    dismiss()
  }
}

/// One rule with its next due date; overdue dates are red and marked with a symbol (F-ERIN-04, NF-07).
struct ReminderRow: View {
  let rule: ReminderRule
  var showsHorse = true

  var body: some View {
    let due = rule.nextDueDate()
    let isOverdue = due.map { $0 < Calendar.current.startOfDay(for: .now) } ?? false
    HStack(spacing: 12) {
      Image(systemName: rule.kind.systemImage)
        .foregroundStyle(Color.categoryTreatments)
        .frame(width: 28)
        .accessibilityHidden(true)
      AdaptiveStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(rule.title)
          Text(subtitle(due: due)).font(.caption).foregroundStyle(.secondary)
        }
        AdaptiveSpacer()
        if let due {
          VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
              if isOverdue {
                Image(systemName: "exclamationmark.circle.fill").accessibilityHidden(true)
              }
              Text(due.formatted(date: .long, time: .omitted))
            }
            .font(.subheadline.weight(isOverdue ? .semibold : .regular))
            Text(isOverdue ? String(localized: "überfällig") : relative(due))
              .font(.caption)
          }
          .foregroundStyle(isOverdue ? Color.red : Color.primary)
        } else {
          Text("Kein Termin").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("reminder.row")
  }

  private func subtitle(due: Date?) -> String {
    var parts: [String] = []
    if showsHorse, let horse = rule.horse { parts.append(horse.name) }
    parts.append(rule.intervalDescription)
    if !rule.isActive { parts.append(String(localized: "pausiert")) }
    if due == nil { parts.append(String(localized: "noch keine passende Behandlung")) }
    return parts.joined(separator: " · ")
  }

  private func relative(_ due: Date) -> String {
    let today = Calendar.current.startOfDay(for: .now)
    if Calendar.current.isDate(due, inSameDayAs: today) { return String(localized: "heute") }
    return due.formatted(.relative(presentation: .named, unitsStyle: .wide))
  }
}

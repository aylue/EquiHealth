import EquiCore
import SwiftData
import SwiftUI

/// "Termine" tab: reminders of all horses grouped by overdue, this month and later (SPEC 5, F-ERIN-04).
struct AppointmentsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AppState.self) private var appState
  @Query private var rules: [ReminderRule]

  private struct Group: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let entries: [(rule: ReminderRule, due: Date?)]
  }

  private var groups: [Group] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let visible = rules.filter { $0.horse?.isArchived != true }
    let active = visible.filter(\.isActive)
      .map { (rule: $0, due: $0.nextDueDate()) }
      .sorted { ($0.due ?? .distantFuture, $0.rule.title) < ($1.due ?? .distantFuture, $1.rule.title) }
    let overdue = active.filter { $0.due.map { $0 < today } ?? false }
    let thisMonth = active.filter {
      $0.due.map { $0 >= today && calendar.isDate($0, equalTo: today, toGranularity: .month) } ?? false
    }
    let later = active.filter {
      $0.due.map { $0 >= today && !calendar.isDate($0, equalTo: today, toGranularity: .month) } ?? false
    }
    let undated = active.filter { $0.due == nil }
    let paused = visible.filter { !$0.isActive }.map { (rule: $0, due: $0.nextDueDate()) }
    return [
      Group(id: "overdue", title: "Überfällig", entries: overdue),
      Group(id: "month", title: "Diesen Monat", entries: thisMonth),
      Group(id: "later", title: "Später", entries: later),
      Group(id: "undated", title: "Ohne Termin", entries: undated),
      Group(id: "paused", title: "Pausiert", entries: paused),
    ].filter { !$0.entries.isEmpty }
  }

  var body: some View {
    NavigationStack {
      List {
        if groups.isEmpty {
          ContentUnavailableView {
            Label("Keine Termine", systemImage: "calendar")
          } description: {
            Text("Lege Erinnerungen für Impfungen, Hufschmied, Zahnkontrolle oder Wurmkur an.")
          } actions: {
            Button("Erinnerung anlegen") { appState.sheet = .newReminder }
              .buttonStyle(.borderedProminent)
              .accessibilityIdentifier("reminders.create")
          }
        }
        ForEach(groups) { group in
          Section(group.title) {
            ForEach(group.entries, id: \.rule.id) { entry in
              Button {
                appState.sheet = .editReminder(entry.rule.id)
              } label: {
                ReminderRow(rule: entry.rule)
              }
              .foregroundStyle(.primary)
              .swipeActions(edge: .leading) {
                Button("Erledigt", systemImage: "checkmark") { appState.sheet = .treatmentForRule(entry.rule.id) }
                  .tint(.green)
              }
              .swipeActions(edge: .trailing) {
                Button("Löschen", systemImage: "trash", role: .destructive) {
                  modelContext.delete(entry.rule)
                  try? modelContext.save()
                }
              }
            }
          }
        }
      }
      .navigationTitle("Termine")
      .appToolbar()
    }
  }
}

#Preview {
  AppointmentsView()
}

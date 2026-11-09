import EquiCore
import Foundation
import SwiftData
import Testing
import UserNotifications

@testable import EquiHealth

@Suite("Mitteilungs-Aktionen (F-ERIN-06, F-ERIN-07)")
@MainActor
struct NotificationRouterTests {
  private struct Fixture {
    let container: ModelContainer
    let appState: AppState
    let router: NotificationRouter
    let ruleID: UUID
  }

  private func makeFixture() throws -> Fixture {
    let name = "NotificationRouterTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let rule = ReminderRule(
      horse: horse, kind: .vaccinationInfluenza, title: "Impfung Influenza", intervalValue: 6, intervalUnit: .months)
    rule.matchingTreatmentKind = .vaccination
    rule.matchingVaccinationTarget = .influenza
    context.insert(rule)
    try context.save()
    let appState = AppState(defaults: defaults)
    appState.showsRemindersOnThisDevice = false  // keep the test host's notification center untouched
    let service = ReminderNotificationService(container: container, appState: appState)
    return Fixture(
      container: container, appState: appState, router: NotificationRouter(appState: appState, service: service),
      ruleID: rule.id)
  }

  @Test("„Erledigt“ und Antippen öffnen die vorbefüllte Behandlungs-Eingabe")
  func doneOpensTreatmentEntry() async throws {
    let fixture = try makeFixture()
    await fixture.router.handle(action: NotificationIdentifiers.doneAction, ruleID: fixture.ruleID)
    #expect(fixture.appState.sheet == .treatmentForRule(fixture.ruleID))

    fixture.appState.sheet = nil
    await fixture.router.handle(action: UNNotificationDefaultActionIdentifier, ruleID: fixture.ruleID)
    #expect(fixture.appState.sheet == .treatmentForRule(fixture.ruleID))
  }

  @Test("„In 1 Woche erinnern“ verschiebt die Erinnerung um sieben Tage zur Erinnerungszeit")
  func snoozePostponesOneWeek() async throws {
    let fixture = try makeFixture()
    let before = Date.now
    await fixture.router.handle(action: NotificationIdentifiers.snoozeAction, ruleID: fixture.ruleID)

    let context = ModelContext(fixture.container)
    let id = fixture.ruleID
    let rule = try #require(
      try context.fetch(FetchDescriptor<ReminderRule>(predicate: #Predicate { $0.id == id })).first)
    let snoozed = try #require(rule.snoozedUntil)
    let expectedDay = Calendar.current.date(byAdding: .day, value: 7, to: before)!
    #expect(Calendar.current.isDate(snoozed, inSameDayAs: expectedDay))
    #expect(Calendar.current.component(.hour, from: snoozed) == rule.reminderHour)
    #expect(fixture.appState.sheet == nil)
  }

  @Test("Unbekannte Aktionen und fehlende Regel-IDs ändern nichts")
  func ignoresUnknownInput() async throws {
    let fixture = try makeFixture()
    await fixture.router.handle(action: "other", ruleID: fixture.ruleID)
    await fixture.router.handle(action: NotificationIdentifiers.doneAction, ruleID: nil)
    #expect(fixture.appState.sheet == nil)
  }

  @Test("F-ERIN-07: Erinnerungen pro Gerät, standardmäßig an; Karenzzeit-Mitteilung standardmäßig aus")
  func perDeviceSettings() {
    let name = "NotificationRouterTests.settings.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    let state = AppState(defaults: defaults)
    #expect(state.showsRemindersOnThisDevice)
    #expect(!state.notifiesCompetitionWithdrawalEnd)
    state.showsRemindersOnThisDevice = false
    state.notifiesCompetitionWithdrawalEnd = true
    let reloaded = AppState(defaults: defaults)
    #expect(!reloaded.showsRemindersOnThisDevice)
    #expect(reloaded.notifiesCompetitionWithdrawalEnd)
  }
}

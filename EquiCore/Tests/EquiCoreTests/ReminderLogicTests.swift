import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Erinnerungen (F-ERIN)")
struct ReminderLogicTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
  }

  private func makeContext() throws -> ModelContext {
    ModelContext(try EquiModelContainer.make(inMemory: true))
  }

  private func influenzaRule(horse: Horse, in context: ModelContext) -> ReminderRule {
    let rule = ReminderRule(
      horse: horse, kind: .vaccinationInfluenza, title: "Impfung Influenza", intervalValue: 6, intervalUnit: .months)
    rule.leadTimeDays = 14
    rule.matchingTreatmentKind = .vaccination
    rule.matchingVaccinationTarget = .influenza
    context.insert(rule)
    return rule
  }

  @discardableResult
  private func vaccinate(
    _ horse: Horse, against targets: [VaccinationTarget], on day: Date, in context: ModelContext
  ) -> Treatment {
    let treatment = Treatment(horse: horse, kind: .vaccination, date: day)
    context.insert(treatment)
    let vaccine = Medication(treatment: treatment, productName: "Impfstoff")
    vaccine.vaccinationTargets = targets
    context.insert(vaccine)
    return treatment
  }

  @Test("Abnahme Phase 4: Influenza alle 6 Monate, 14 Tage Vorlauf ergibt das richtige Fälligkeitsdatum")
  func influenzaAcceptance() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let rule = influenzaRule(horse: horse, in: context)
    vaccinate(horse, against: [.influenza, .tetanus], on: date(2026, 11, 9, 10), in: context)
    try context.save()

    #expect(rule.nextDueDate(calendar: calendar) == date(2027, 5, 9))

    let plan = ReminderPlanner.plan(rules: [rule], now: date(2026, 11, 9, 12), calendar: calendar)
    #expect(plan.map(\.kind) == [.leadTime, .due])
    #expect(plan[0].fireDate == date(2027, 4, 25, 9), "14 Tage vorher um 9:00")
    #expect(plan[1].fireDate == date(2027, 5, 9, 9))
    #expect(plan.allSatisfy { $0.referenceDate == date(2027, 5, 9) && $0.sourceID == rule.id })
  }

  @Test("F-ERIN-01: Nur passende Behandlungen zählen, die jüngste gewinnt")
  func matchingTreatments() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let rule = influenzaRule(horse: horse, in: context)
    vaccinate(horse, against: [.influenza], on: date(2026, 1, 10), in: context)
    vaccinate(horse, against: [.herpes], on: date(2026, 9, 1), in: context)
    context.insert(Treatment(horse: horse, kind: .veterinarian, date: date(2026, 10, 1)))
    try context.save()
    #expect(rule.lastFulfilledDate == date(2026, 1, 10))
    #expect(rule.nextDueDate(calendar: calendar) == date(2026, 7, 10))
  }

  @Test("Ohne passende Behandlung gilt das Startdatum; ohne beides keine Fälligkeit")
  func startDateFallback() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let rule = ReminderRule(horse: horse, kind: .farrier, title: "Hufschmied", intervalValue: 6, intervalUnit: .weeks)
    rule.matchingTreatmentKind = .farrier
    context.insert(rule)
    #expect(rule.nextDueDate(calendar: calendar) == nil)
    rule.startDate = date(2026, 11, 20, 15)
    #expect(rule.nextDueDate(calendar: calendar) == date(2026, 11, 20))

    context.insert(Treatment(horse: horse, kind: .farrier, date: date(2026, 11, 9, 8)))
    try context.save()
    #expect(rule.nextDueDate(calendar: calendar) == date(2026, 12, 21), "6 Wochen nach dem Hufschmied")
  }

  @Test("F-ERIN-06: „In 1 Woche erinnern“ ersetzt Vorlauf- und Fälligkeitsmitteilung")
  func snooze() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let rule = influenzaRule(horse: horse, in: context)
    rule.startDate = date(2026, 11, 9)
    rule.snoozedUntil = date(2026, 11, 16, 9)
    try context.save()
    let plan = ReminderPlanner.plan(rules: [rule], now: date(2026, 11, 9, 12), calendar: calendar)
    #expect(plan.map(\.kind) == [.snoozed])
    #expect(plan.first?.fireDate == date(2026, 11, 16, 9))
  }

  @Test("F-ERIN-05: Höchstens 64 Mitteilungen, die frühesten zuerst; inaktive und archivierte Regeln fehlen")
  func limitAndFilters() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    let archived = Horse(name: "Alt")
    archived.isArchived = true
    context.insert(horse)
    context.insert(archived)
    var rules: [ReminderRule] = []
    for index in 0..<50 {
      let rule = ReminderRule(
        horse: horse, kind: .custom, title: "Regel \(index)", intervalValue: 1, intervalUnit: .years)
      rule.startDate = date(2027, 1, 1 + index % 28)
      rule.leadTimeDays = 7
      context.insert(rule)
      rules.append(rule)
    }
    let inactive = ReminderRule(horse: horse, kind: .custom, title: "Inaktiv", intervalValue: 1, intervalUnit: .years)
    inactive.startDate = date(2026, 12, 1)
    inactive.isActive = false
    let ofArchived = ReminderRule(
      horse: archived, kind: .custom, title: "Archiv", intervalValue: 1, intervalUnit: .years)
    ofArchived.startDate = date(2026, 12, 1)
    for rule in [inactive, ofArchived] { context.insert(rule) }
    try context.save()

    let plan = ReminderPlanner.plan(
      rules: rules + [inactive, ofArchived], now: date(2026, 11, 9), calendar: calendar)
    #expect(plan.count == 64)
    #expect(plan == plan.sorted { $0.fireDate < $1.fireDate })
    #expect(!plan.contains { $0.sourceID == inactive.id || $0.sourceID == ofArchived.id })
    #expect(Set(plan.map(\.identifier)).count == plan.count, "Eindeutige Kennungen")
  }

  @Test("Vergangene Termine werden nicht geplant")
  func pastDatesAreSkipped() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let rule = influenzaRule(horse: horse, in: context)
    rule.startDate = date(2026, 11, 1)
    try context.save()
    #expect(ReminderPlanner.plan(rules: [rule], now: date(2026, 11, 9), calendar: calendar).isEmpty)
  }

  @Test("F-BEH-11: Mitteilung am Tag nach dem Ende der Turnier-Karenzzeit")
  func competitionWithdrawalEnd() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let treatment = Treatment(horse: horse, kind: .veterinarian, date: date(2026, 11, 9, 10))
    context.insert(treatment)
    let medication = Medication(treatment: treatment, productName: "Präparat")
    medication.competitionWithdrawalDays = 9
    context.insert(medication)
    try context.save()
    let plan = ReminderPlanner.plan(
      rules: [], medications: [medication], now: date(2026, 11, 9, 12), calendar: calendar)
    #expect(plan.map(\.kind) == [.competitionWithdrawalEnded])
    #expect(plan.first?.fireDate == date(2026, 11, 19, 9))
    #expect(plan.first?.referenceDate == date(2026, 11, 18))
  }

  @Test("Intervalle in Tagen, Wochen, Monaten, Jahren")
  func intervals() {
    let start = date(2026, 1, 31)
    #expect(IntervalUnit.days.add(10, to: start, calendar: calendar) == date(2026, 2, 10))
    #expect(IntervalUnit.weeks.add(2, to: start, calendar: calendar) == date(2026, 2, 14))
    #expect(IntervalUnit.months.add(1, to: start, calendar: calendar) == date(2026, 2, 28))
    #expect(IntervalUnit.years.add(1, to: start, calendar: calendar) == date(2027, 1, 31))
  }
}

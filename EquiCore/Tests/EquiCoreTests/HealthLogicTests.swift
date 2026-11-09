import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Gesundheit und Behandlungen (F-GESUND, F-BEH)")
struct HealthLogicTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
  }

  private func makeContext() throws -> ModelContext {
    ModelContext(try EquiModelContainer.make(inMemory: true))
  }

  @Test("F-BEH-08: Enddatum aus Tagen ab letzter Gabe oder als festes Datum")
  func withdrawalEndDates() {
    let lastDose = date(2026, 11, 9, 18)
    #expect(
      WithdrawalCalculator.endDate(until: nil, days: 5, lastDose: lastDose, calendar: calendar)
        == date(2026, 11, 14, 0))
    #expect(
      WithdrawalCalculator.endDate(until: date(2026, 11, 18, 15), days: 5, lastDose: lastDose, calendar: calendar)
        == date(2026, 11, 18, 0), "Festes Datum hat Vorrang")
    #expect(WithdrawalCalculator.endDate(until: nil, days: nil, lastDose: lastDose, calendar: calendar) == nil)
    #expect(WithdrawalCalculator.endDate(until: nil, days: 5, lastDose: nil, calendar: calendar) == nil)
  }

  @Test("F-BEH-08: Letzte Gabe = Ende, sonst Beginn, sonst Behandlungsdatum")
  func lastDose() throws {
    let context = try makeContext()
    let treatment = Treatment(horse: nil, kind: .veterinarian, date: date(2026, 11, 1))
    context.insert(treatment)
    let medication = Medication(treatment: treatment, productName: "Präparat")
    context.insert(medication)
    #expect(medication.lastDoseDate == date(2026, 11, 1))
    medication.startDate = date(2026, 11, 2)
    #expect(medication.lastDoseDate == date(2026, 11, 2))
    medication.endDate = date(2026, 11, 6)
    #expect(medication.lastDoseDate == date(2026, 11, 6))
    medication.competitionWithdrawalDays = 12
    #expect(medication.withdrawalEnd(.competition, calendar: calendar) == date(2026, 11, 18, 0))
    #expect(medication.withdrawalEnd(.food, calendar: calendar) == nil)
  }

  @Test("F-BEH-09: Laufende Warte- und Karenzzeiten, inklusive Endtag")
  func activeWithdrawals() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let treatment = Treatment(horse: horse, kind: .veterinarian, date: date(2026, 11, 9))
    context.insert(treatment)
    let medication = Medication(treatment: treatment, productName: "Flunixin")
    medication.foodWithdrawalDays = 10
    medication.competitionWithdrawalUntil = date(2026, 11, 12)
    context.insert(medication)
    try context.save()

    let onNov12 = horse.activeWithdrawals(on: date(2026, 11, 12, 20), calendar: calendar)
    #expect(onNov12.map(\.kind) == [.competition, .food])
    let onNov13 = horse.activeWithdrawals(on: date(2026, 11, 13), calendar: calendar)
    #expect(onNov13.map(\.kind) == [.food])
    #expect(horse.activeWithdrawals(on: date(2026, 11, 20), calendar: calendar).isEmpty)
  }

  @Test("F-GESUND-03: Laufende Symptome; F-GESUND-04: chronische, nicht ausgeheilte Krankheiten")
  func ongoingAndChronic() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let cough = SymptomEntry(horse: horse, category: .cough, severity: .mild, startDate: date(2026, 11, 1))
    let colic = SymptomEntry(horse: horse, category: .colic, severity: .severe, startDate: date(2026, 11, 5))
    let ended = SymptomEntry(horse: horse, category: .lameness, severity: .moderate, startDate: date(2026, 10, 1))
    ended.endDate = date(2026, 10, 3)
    [cough, colic, ended].forEach { context.insert($0) }
    context.insert(Condition(horse: horse, name: "Equines Asthma", isChronic: true))
    let healed = Condition(horse: horse, name: "Sommerekzem", isChronic: true)
    healed.healedAt = date(2026, 9, 1)
    context.insert(healed)
    context.insert(Condition(horse: horse, name: "Hufabszess"))
    try context.save()

    #expect(horse.ongoingSymptoms.map(\.category) == [.colic, .cough])
    #expect(horse.chronicConditions.map(\.name) == ["Equines Asthma"])
  }

  @Test("F-GESUND-06: Zeitleiste sortiert und nach Art filterbar")
  func timeline() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let colic = SymptomEntry(horse: horse, category: .colic, severity: .severe, startDate: date(2026, 11, 5, 8))
    let visit = Treatment(horse: horse, kind: .veterinarian, date: date(2026, 11, 5, 10))
    let condition = Condition(horse: horse, name: "Krampfkolik", diagnosedAt: date(2026, 11, 5, 11))
    context.insert(colic)
    context.insert(visit)
    context.insert(condition)
    try context.save()

    #expect(horse.timeline().map(\.kind) == [.condition, .treatment, .symptom])
    #expect(horse.timeline(kinds: [.symptom, .treatment]).map(\.id) == [visit.id, colic.id])
  }

  @Test("F-BEH-04: Letzte Impfung pro Krankheit")
  func lastVaccinations() throws {
    let context = try makeContext()
    let horse = Horse(name: "Luna")
    context.insert(horse)
    for (day, targets) in [(1, [VaccinationTarget.influenza, .tetanus]), (20, [.influenza])] {
      let treatment = Treatment(horse: horse, kind: .vaccination, date: date(2026, 5, day))
      context.insert(treatment)
      let vaccine = Medication(treatment: treatment, productName: "Impfstoff")
      vaccine.vaccinationTargets = targets
      context.insert(vaccine)
    }
    let notVaccination = Treatment(horse: horse, kind: .veterinarian, date: date(2026, 6, 1))
    context.insert(notVaccination)
    let medication = Medication(treatment: notVaccination, productName: "Andere")
    medication.vaccinationTargets = [.herpes]
    context.insert(medication)
    try context.save()

    let result = horse.lastVaccinations()
    #expect(result[.influenza] == date(2026, 5, 20))
    #expect(result[.tetanus] == date(2026, 5, 1))
    #expect(result[.herpes] == nil, "Nur Behandlungen der Art Impfung zählen")
  }
}

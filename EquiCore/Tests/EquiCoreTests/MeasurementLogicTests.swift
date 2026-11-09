import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Messwert-Logik (F-MESS)")
struct MeasurementLogicTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
  }

  @Test("F-MESS-07: Gewicht = Brustumfang² × Körperlänge ÷ 11.880")
  func weightEstimationFormula() throws {
    let weight = try #require(WeightEstimation.estimatedWeight(chestGirthCM: 200, bodyLengthCM: 165))
    #expect(abs(weight - 555.555) < 0.01)
    let pony = try #require(WeightEstimation.estimatedWeight(chestGirthCM: 150, bodyLengthCM: 120))
    #expect(abs(pony - 227.27) < 0.01)
  }

  @Test("F-MESS-07: Ungültige Maße ergeben keine Schätzung", arguments: [(0.0, 160.0), (-1, 160), (190, 0)])
  func weightEstimationRejectsInvalidInput(girth: Double, length: Double) {
    #expect(WeightEstimation.estimatedWeight(chestGirthCM: girth, bodyLengthCM: length) == nil)
  }

  @Test("F-MESS-03: Zeiträume T/W/M/6M/J enden mit dem heutigen Tag")
  func chartTimeRanges() throws {
    let now = date(2026, 11, 9, 15)
    let day = try #require(ChartTimeRange.day.interval(now: now, calendar: calendar))
    #expect(day.start == date(2026, 11, 9, 0))
    #expect(day.end == date(2026, 11, 10, 0))
    let week = try #require(ChartTimeRange.week.interval(now: now, calendar: calendar))
    #expect(week.start == date(2026, 11, 3, 0))
    let sixMonths = try #require(ChartTimeRange.sixMonths.interval(now: now, calendar: calendar))
    #expect(sixMonths.start == date(2026, 5, 10, 0))
    let year = try #require(ChartTimeRange.year.interval(now: now, calendar: calendar))
    #expect(year.start == date(2025, 11, 10, 0))
    #expect(ChartTimeRange.all.interval(now: now, calendar: calendar) == nil)
  }

  @Test("F-MESS-03: „Alle“ umfasst die Spanne der Daten")
  func allRangeSpansData() {
    let now = date(2026, 11, 9)
    let domain = ChartTimeRange.all.domain(
      for: [date(2020, 3, 1, 8), date(2024, 1, 1)], now: now, calendar: calendar)
    #expect(domain.start == date(2020, 3, 1, 0))
    #expect(domain.end == date(2026, 11, 10, 0))
  }

  @Test("F-MESS-04: Referenzbereich ordnet Werte ein")
  func referenceRange() {
    let range = ReferenceRange(lower: 38.2, upper: 37.2)
    #expect(range.lower == 37.2)
    #expect(range.classify(36.9) == .below)
    #expect(range.classify(37.8) == .within)
    #expect(range.classify(38.2) == .within)
    #expect(range.classify(38.6) == .above)
  }

  @Test("Dezimaleingabe mit Komma und Punkt", arguments: [("540,5", 540.5), ("540.5", 540.5), (" 38 ", 38.0)])
  func decimalInput(text: String, expected: Double) {
    #expect(DecimalInput.parse(text, locale: Locale(identifier: "de_DE")) == expected)
  }

  @Test("Ungültige Dezimaleingaben", arguments: ["", "abc", "1,2,3"])
  func invalidDecimalInput(text: String) {
    #expect(DecimalInput.parse(text, locale: Locale(identifier: "de_DE")) == nil)
  }

  @Test("F-MESS-09: Methode Schätzformel markiert den Wert als geschätzt")
  func estimatedFlag() {
    #expect(BodyMeasurement(horse: nil, type: .weight, value: 500, method: .estimationFormula).isEstimated)
    #expect(!BodyMeasurement(horse: nil, type: .weight, value: 500, method: .scale).isEstimated)
  }
}

@Suite("Pferde-Logik (F-PFERD)")
struct HorseLogicTests {
  @Test("F-PFERD-03: Alter in Jahren und Monaten")
  func age() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    let birth = calendar.date(from: DateComponents(year: 2014, month: 5, day: 20))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9))!
    let age = try #require(HorseAge.components(birthDate: birth, now: now, calendar: calendar))
    #expect(age.year == 12)
    #expect(age.month == 5)
    #expect(HorseAge.components(birthDate: now.addingTimeInterval(86_400), now: now) == nil)
  }

  @Test("F-PFERD-02: Aktives Pferd bleibt erhalten, sonst das erste")
  func activeHorseResolution() {
    let luna = Horse(name: "Luna")
    let max = Horse(name: "Max")
    #expect(ActiveHorseSelection.resolve(storedID: max.id, in: [luna, max]) === max)
    #expect(ActiveHorseSelection.resolve(storedID: UUID(), in: [luna, max]) === luna)
    #expect(ActiveHorseSelection.resolve(storedID: nil, in: [luna, max]) === luna)
    #expect(ActiveHorseSelection.resolve(storedID: nil, in: []) == nil)
  }

  @Test("F-PFERD-04: Umzug beendet die alte Zuordnung und beginnt eine neue")
  func moveToStable() throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let horse = Horse(name: "Luna")
    let oldStable = Stable(name: "Hof Sonnenschein")
    let newStable = Stable(name: "Reitverein Nord")
    context.insert(horse)
    context.insert(oldStable)
    context.insert(newStable)

    let start = Date(timeIntervalSince1970: 1_700_000_000)
    let moveDate = start.addingTimeInterval(86_400 * 100)
    let first = horse.move(to: oldStable, on: start, in: context)
    let second = horse.move(to: newStable, on: moveDate, in: context)
    try context.save()

    #expect(first.validUntil == moveDate)
    #expect(second.validUntil == nil)
    #expect(horse.stableAssignment(at: start.addingTimeInterval(86_400))?.stable === oldStable)
    #expect(horse.stableAssignment(at: moveDate)?.stable === newStable)
    #expect(horse.stableAssignment(at: start.addingTimeInterval(-1)) == nil)
    #expect(horse.stableAssignments?.count == 2)
  }

  @Test("F-PFERD-03: Jüngster Messwert pro Typ")
  func latestMeasurement() throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let now = Date()
    context.insert(BodyMeasurement(horse: horse, type: .weight, value: 520, timestamp: now.addingTimeInterval(-86_400)))
    context.insert(BodyMeasurement(horse: horse, type: .weight, value: 530, timestamp: now))
    context.insert(BodyMeasurement(horse: horse, type: .bodyTemperature, value: 37.6, timestamp: now))
    try context.save()
    #expect(horse.latestMeasurement(of: .weight)?.value == 530)
    #expect(horse.latestMeasurement(of: .heightAtWithers) == nil)
  }
}

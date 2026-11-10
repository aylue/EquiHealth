import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Fütterung (F-FUTTER)")
struct FeedingLogicTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
  }

  private struct Fixture {
    let context: ModelContext
    let horse: Horse
    let hay: Feed
    let oats: Feed
    let mineral: Feed
    var feeds: [Feed] { [hay, oats, mineral] }
  }

  private func makeFixture() throws -> Fixture {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let horse = Horse(name: "Luna")
    let hay = Feed(name: "Heu", category: .roughage, defaultUnit: .kilogram)
    let oats = Feed(name: "Hafer", category: .concentrate, defaultUnit: .gram)
    let mineral = Feed(name: "Mineral", category: .mineral, defaultUnit: .scoop)
    for model in [hay, oats, mineral] as [any PersistentModel] { context.insert(model) }
    context.insert(horse)
    return Fixture(context: context, horse: horse, hay: hay, oats: oats, mineral: mineral)
  }

  @Test("F-FUTTER-03/-05: Nach einer Änderung zeigt ein Tag vor der Änderung den alten Plan")
  func planVersions() throws {
    let f = try makeFixture()
    f.horse.applyFeedingPlan(
      [
        FeedingPlanLine(feedID: f.hay.id, amount: 8, unit: .kilogram, meal: .adLibitum),
        FeedingPlanLine(feedID: f.oats.id, amount: 500, unit: .gram, meal: .morning),
      ], from: date(2026, 10, 1), feeds: f.feeds, in: f.context, calendar: calendar)
    try f.context.save()

    f.horse.applyFeedingPlan(
      [
        FeedingPlanLine(feedID: f.hay.id, amount: 9, unit: .kilogram, meal: .adLibitum),
        FeedingPlanLine(feedID: f.oats.id, amount: 500, unit: .gram, meal: .morning),
        FeedingPlanLine(feedID: f.mineral.id, amount: 1, unit: .scoop, meal: .evening),
      ], from: date(2026, 11, 1), feeds: f.feeds, in: f.context, calendar: calendar)
    try f.context.save()

    let before = f.horse.feedingPlan(at: date(2026, 10, 31))
    #expect(before.map(\.feed?.name) == ["Hafer", "Heu"])
    #expect(before.first { $0.feed === f.hay }?.amount == 8)

    let after = f.horse.feedingPlan(at: date(2026, 11, 1))
    #expect(after.map(\.feed?.name) == ["Hafer", "Mineral", "Heu"])
    #expect(after.first { $0.feed === f.hay }?.amount == 9)

    // Unchanged oats item is kept, not duplicated.
    #expect((f.horse.feedingPlanItems ?? []).filter { $0.feed === f.oats }.count == 1)
    #expect(f.horse.feedingPlanVersionDates == [date(2026, 11, 1, 0), date(2026, 10, 1, 0)])
    #expect(f.horse.feedingPlan(at: date(2026, 9, 30)).isEmpty)
  }

  @Test("F-FUTTER-03: Zweite Änderung am selben Tag ersetzt statt leere Versionen anzulegen")
  func sameDayEditReplaces() throws {
    let f = try makeFixture()
    let day = date(2026, 11, 9)
    f.horse.applyFeedingPlan(
      [FeedingPlanLine(feedID: f.hay.id, amount: 8, unit: .kilogram, meal: .adLibitum)],
      from: day, feeds: f.feeds, in: f.context, calendar: calendar)
    try f.context.save()
    f.horse.applyFeedingPlan(
      [FeedingPlanLine(feedID: f.hay.id, amount: 7, unit: .kilogram, meal: .adLibitum)],
      from: day, feeds: f.feeds, in: f.context, calendar: calendar)
    try f.context.save()

    #expect(try f.context.fetchCount(FetchDescriptor<FeedingPlanItem>()) == 1)
    #expect(f.horse.feedingPlan(at: day).first?.amount == 7)
  }

  @Test("F-FUTTER-03: Entfernte Positionen enden am Änderungstag")
  func removedItemsEnd() throws {
    let f = try makeFixture()
    f.horse.applyFeedingPlan(
      [FeedingPlanLine(feedID: f.oats.id, amount: 1, unit: .kilogram, meal: .evening)],
      from: date(2026, 10, 1), feeds: f.feeds, in: f.context, calendar: calendar)
    f.horse.applyFeedingPlan([], from: date(2026, 11, 1), feeds: f.feeds, in: f.context, calendar: calendar)
    try f.context.save()

    let items = f.horse.feedingPlanItems ?? []
    #expect(items.count == 1)
    #expect(items.first?.validUntil == date(2026, 11, 1, 0))
    #expect(f.horse.feedingPlan(at: date(2026, 11, 2)).isEmpty)
  }

  @Test("F-FUTTER-04/-05: Zusatzgaben gehören zum Kalendertag")
  func logsPerDay() throws {
    let f = try makeFixture()
    f.context.insert(
      FeedingLog(horse: f.horse, feed: f.oats, amount: 200, unit: .gram, timestamp: date(2026, 11, 9, 8)))
    f.context.insert(
      FeedingLog(horse: f.horse, feed: f.hay, amount: 1, unit: .kilogram, timestamp: date(2026, 11, 10, 8)))
    try f.context.save()
    #expect(f.horse.feedingLogs(onDayOf: date(2026, 11, 9, 20), calendar: calendar).map(\.feed?.name) == ["Hafer"])
  }

  @Test("F-FUTTER-06: Tagesmenge pro Kategorie in kg aus Plan und Zusatzgaben")
  func dailyTotals() throws {
    let f = try makeFixture()
    f.horse.applyFeedingPlan(
      [
        FeedingPlanLine(feedID: f.hay.id, amount: 8, unit: .kilogram, meal: .adLibitum),
        FeedingPlanLine(feedID: f.oats.id, amount: 500, unit: .gram, meal: .morning),
        FeedingPlanLine(feedID: f.oats.id, amount: 500, unit: .gram, meal: .evening),
        FeedingPlanLine(feedID: f.mineral.id, amount: 1, unit: .scoop, meal: .evening),
      ], from: date(2026, 11, 9), feeds: f.feeds, in: f.context, calendar: calendar)
    f.context.insert(
      FeedingLog(horse: f.horse, feed: f.oats, amount: 250, unit: .gram, timestamp: date(2026, 11, 10, 8)))
    try f.context.save()

    let totals = f.horse.dailyFeedTotals(from: date(2026, 11, 8), through: date(2026, 11, 10), calendar: calendar)
    func kg(_ day: Int, _ category: FeedCategory) -> Double? {
      totals.first { $0.day == date(2026, 11, day, 0) && $0.category == category }?.kilograms
    }
    #expect(kg(8, .roughage) == nil, "Vor Planbeginn keine Mengen")
    #expect(kg(9, .roughage) == 8)
    #expect(kg(9, .concentrate) == 1)
    #expect(kg(10, .concentrate) == 1.25)
    #expect(kg(9, .mineral) == nil, "Messbecher sind nicht in kg umrechenbar")
  }
}

@Suite("Abweichungen vom Futterplan (F-FUTTER-04, F-FUTTER-05, Q-033)")
struct FeedingDeviationTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
  }

  @Test("Position für einen Tag auslassen oder mit anderer Menge füttern, wieder zurücksetzen")
  func deviations() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let horse = Horse(name: "Luna")
    let hay = Feed(name: "Heu", category: .roughage)
    let oats = Feed(name: "Hafer", category: .concentrate)
    context.insert(horse)
    context.insert(hay)
    context.insert(oats)
    horse.applyFeedingPlan(
      [
        FeedingPlanLine(feedID: hay.id, amount: 8, unit: .kilogram, meal: .adLibitum),
        FeedingPlanLine(feedID: oats.id, amount: 500, unit: .gram, meal: .morning),
      ], from: date(2026, 11, 1), feeds: [hay, oats], in: context, calendar: calendar)
    try context.save()

    let day = date(2026, 11, 9, 7)
    let entries = horse.feedingDay(day, calendar: calendar)
    let hayItem = try #require(entries.first { $0.planItem.feed === hay }?.planItem)
    let oatsItem = try #require(entries.first { $0.planItem.feed === oats }?.planItem)

    horse.setFeedingDeviation(for: oatsItem, on: day, amount: nil, unit: .gram, in: context, calendar: calendar)
    horse.setFeedingDeviation(for: hayItem, on: day, amount: 4, unit: .kilogram, in: context, calendar: calendar)
    horse.setFeedingDeviation(for: hayItem, on: day, amount: 5, unit: .kilogram, in: context, calendar: calendar)
    context.insert(FeedingLog(horse: horse, feed: oats, amount: 200, unit: .gram, timestamp: date(2026, 11, 9, 18)))
    try context.save()

    let changed = horse.feedingDay(day, calendar: calendar)
    #expect(changed.first { $0.planItem === oatsItem }?.isOmitted == true)
    #expect(changed.first { $0.planItem === oatsItem }?.effectiveAmount == 0)
    #expect(changed.first { $0.planItem === hayItem }?.effectiveAmount == 5, "Zweite Änderung ersetzt die erste")
    #expect(horse.extraFeedingLogs(onDayOf: day, calendar: calendar).count == 1)
    #expect(try context.fetchCount(FetchDescriptor<FeedingLog>()) == 3)

    let totals = horse.dailyFeedTotals(from: day, through: day, calendar: calendar)
    #expect(totals.first { $0.category == .roughage }?.kilograms == 5)
    #expect(totals.first { $0.category == .concentrate }?.kilograms == 0.2, "Nur die Zusatzgabe zählt")

    // Other days are not affected.
    #expect(horse.feedingDay(date(2026, 11, 10), calendar: calendar).allSatisfy { $0.deviation == nil })

    horse.clearFeedingDeviation(for: hayItem, on: day, in: context, calendar: calendar)
    try context.save()
    #expect(horse.feedingDay(day, calendar: calendar).first { $0.planItem === hayItem }?.effectiveAmount == 8)
  }
}

@Suite("Wochenmittel der Tagesmengen (F-FUTTER-06, NF-04)")
struct WeeklyFeedAverageTests {
  @Test("Mittel pro Tag und Woche; Tage ohne Eintrag zählen mit 0 kg; Teilwochen nur mit ihren Tagen")
  func weeklyAverages() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    calendar.firstWeekday = 2
    func day(_ d: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: d))! }
    // Mon 2.11. – Sun 8.11., then Mon 9.11. – Wed 11.11.
    let totals = [
      DailyFeedTotal(day: day(2), category: .roughage, kilograms: 8),
      DailyFeedTotal(day: day(3), category: .roughage, kilograms: 6),
      DailyFeedTotal(day: day(9), category: .roughage, kilograms: 9),
      DailyFeedTotal(day: day(10), category: .concentrate, kilograms: 0.6),
    ]
    let weeks = totals.weeklyAverages(from: day(2), through: day(11), calendar: calendar)
    #expect(weeks.count == 3)
    #expect(weeks[0] == WeeklyFeedAverage(weekStart: day(2), category: .roughage, kilogramsPerDay: 2))
    #expect(weeks[1] == WeeklyFeedAverage(weekStart: day(9), category: .roughage, kilogramsPerDay: 3))
    #expect(abs(weeks[2].kilogramsPerDay - 0.2) < 1e-9)
  }
}

import Foundation
import SwiftData
import Testing

@testable import EquiCore

/// NF-04: 10 horses over 10 years (≈ 50,000 entries); typical evaluations stay fast.
@Suite("Leistung mit großem Datenbestand (NF-04)", .serialized)
struct LargeDataTests {
  private func measure<T>(_ label: String, _ limit: Duration, _ work: () throws -> T) rethrows -> T {
    let clock = ContinuousClock()
    var result: T?
    let elapsed = try clock.measure { result = try work() }
    print("NF-04 \(label): \(elapsed.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow)))")
    #expect(elapsed < limit, "\(label) dauerte \(elapsed)")
    return result!
  }

  @Test("10 Pferde, 10 Jahre: Erzeugung und Auswertungen")
  func largeDataSet() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let clock = ContinuousClock()
    var summary: LargeDataGenerator.Summary?
    let generation = try await clock.measure {
      summary = try await LargeDataGenerator(modelContainer: container).generate()
    }
    print("NF-04 Erzeugung: \(generation) für \(summary?.entries ?? 0) Einträge")
    let entries = try #require(summary?.entries)
    #expect((45_000...60_000).contains(entries), "≈ 50.000 Einträge, erzeugt: \(entries)")
    #expect(generation < .seconds(120))

    let context = ModelContext(container)
    let horses = try context.fetch(FetchDescriptor<Horse>())
    #expect(horses.count == 10)
    let horse = try #require(horses.first { $0.name == "Testpferd 1" })

    let weights = measure("Gewichte eines Pferdes sortiert", .seconds(1)) {
      (horse.measurements ?? []).filter { $0.type == .weight }.sorted { $0.timestamp < $1.timestamp }
    }
    #expect(weights.count > 500)
    _ = measure("Fütterung eines Jahres (Tagesmengen)", .seconds(2)) {
      horse.dailyFeedTotals(
        from: Calendar.current.date(byAdding: .year, value: -1, to: .now)!, through: .now)
    }
    _ = measure("Trainingswochen (8)", .seconds(1)) { horse.trainingWeeks(8) }
    _ = measure("Laufende Wartezeiten", .seconds(1)) { horse.activeWithdrawals() }
    _ = try measure("Erinnerungsplan aller Pferde", .seconds(2)) {
      ReminderPlanner.plan(rules: try context.fetch(FetchDescriptor<ReminderRule>()))
    }

    let clockSearch = ContinuousClock()
    var hits: [SearchHit] = []
    let searchTime = try await clockSearch.measure {
      hits = try await FullTextSearch(modelContainer: container).search("Beobachtung 12")
    }
    print("NF-04 Volltextsuche: \(searchTime)")
    #expect(!hits.isEmpty)
    #expect(searchTime < .seconds(5))

    var files: [ExportFile] = []
    let exportTime = try await clock.measure {
      files = try await CSVExporter(modelContainer: container).makeFiles(
        horseIDs: Set(horses.map(\.id)), areas: Set(CSVArea.allCases), interval: nil, format: .excelGerman)
    }
    print("NF-04 CSV-Export: \(exportTime)")
    #expect(files.map(\.rowCount).reduce(0, +) > 40_000)
    #expect(exportTime < .seconds(30))

    try await LargeDataGenerator(modelContainer: container).removeGeneratedData()
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<BodyMeasurement>()) == 0)
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<Feed>()) == 0)
  }
}

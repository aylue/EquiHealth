import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("CSV-Export (F-CSV)")
struct CSVExportTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
  }

  private func text(_ data: Data) -> String {
    String(decoding: data.dropFirst(3), as: UTF8.self)
  }

  @Test(
    "F-CSV-05: RFC-4180-Maskierung von Trennzeichen, Anführungszeichen und Zeilenumbrüchen",
    arguments: [
      ("einfach", ";", "einfach"),
      ("a;b", ";", "\"a;b\""),
      ("a,b", ";", "a,b"),
      ("a,b", ",", "\"a,b\""),
      ("Sagt \"Hü\"", ";", "\"Sagt \"\"Hü\"\"\""),
      ("Zeile 1\nZeile 2", ";", "\"Zeile 1\nZeile 2\""),
      ("Wagen\rRücklauf", ",", "\"Wagen\rRücklauf\""),
      ("", ";", ""),
    ])
  func escaping(input: String, separator: String, expected: String) {
    #expect(CSVWriter.escape(input, separator: Character(separator)) == expected)
  }

  @Test("F-CSV-03: Excel (Deutsch) mit Semikolon und Dezimalkomma, UTF-8 mit BOM, CRLF")
  func excelGermanFormat() {
    let table = CSVTable(
      fileName: "Test.csv", header: ["Name", "Wert", "Zeitpunkt", "Tag", "Ja/Nein"],
      rows: [
        [
          .text("Größe; Übersicht"), .number(540.5), .timestamp(date(2026, 11, 9, 10)), .day(date(2014, 5, 20)),
          .bool(true),
        ]
      ])
    let data = CSVWriter.data(for: table, format: .excelGerman, timeZone: calendar.timeZone)
    #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF], "BOM")
    #expect(
      text(data)
        == "Name;Wert;Zeitpunkt;Tag;Ja/Nein\r\n\"Größe; Übersicht\";540,5;2026-11-09T10:00:00+01:00;2014-05-20;ja\r\n")
  }

  @Test("F-CSV-03: Standard mit Komma und Dezimalpunkt")
  func standardFormat() {
    let table = CSVTable(
      fileName: "Test.csv", header: ["Wert", "Ganzzahl", "Leer", "Text"],
      rows: [[.number(37.65), .number(540), .empty, .text("a,b")]])
    #expect(
      text(CSVWriter.data(for: table, format: .standard, timeZone: calendar.timeZone))
        == "Wert,Ganzzahl,Leer,Text\r\n37.65,540,,\"a,b\"\r\n")
  }

  @Test("F-CSV-01/-02/F-BEH-12: Tabellen pro Bereich, Filter nach Pferd und Zeitraum, Enddaten der Wartezeiten")
  func tables() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let luna = Horse(name: "Luna")
    let max = Horse(name: "Max")
    context.insert(luna)
    context.insert(max)
    context.insert(
      BodyMeasurement(horse: luna, type: .weight, value: 540, timestamp: date(2026, 1, 10), method: .scale))
    context.insert(
      BodyMeasurement(horse: luna, type: .weight, value: 545, timestamp: date(2026, 6, 10), method: .estimationFormula))
    context.insert(BodyMeasurement(horse: max, type: .weight, value: 610, timestamp: date(2026, 6, 10), method: .scale))
    let treatment = Treatment(horse: luna, kind: .veterinarian, date: date(2026, 6, 1, 10))
    context.insert(treatment)
    let medication = Medication(treatment: treatment, productName: "Flunixin")
    medication.foodWithdrawalDays = 5
    medication.competitionWithdrawalUntil = date(2026, 6, 20)
    context.insert(medication)
    try context.save()

    let interval = DateInterval(start: date(2026, 5, 1), end: date(2026, 12, 31))
    let tables = CSVExportBuilder.tables(horses: [luna], interval: interval, calendar: calendar)
    #expect(tables.map(\.fileName) == CSVArea.allCases.map(\.fileName))
    #expect(tables.allSatisfy { table in table.rows.allSatisfy { $0.count == table.header.count } }, "Spaltenzahl")

    let measurements = try #require(tables.first { $0.fileName == "Messwerte.csv" })
    #expect(measurements.rows.count == 1, "Nur Luna, nur im Zeitraum")
    #expect(measurements.rows.first?[3] == .number(545))
    #expect(measurements.rows.first?[7] == .bool(true), "geschätzt")

    let medications = try #require(tables.first { $0.fileName == "Medikamente.csv" })
    let header = medications.header
    let row = try #require(medications.rows.first)
    #expect(row[try #require(header.firstIndex(of: "Wartezeit Lebensmittel bis"))] == .day(date(2026, 6, 6)))
    #expect(row[try #require(header.firstIndex(of: "Karenzzeit Turnier bis"))] == .day(date(2026, 6, 20)))

    let horses = try #require(tables.first { $0.fileName == "Pferde.csv" })
    #expect(horses.rows.count == 1)
  }

  @Test("Export-Actor liefert Dateien mit Zeilenzahl")
  func exporter() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let horse = Horse(name: "Lünä")
    context.insert(horse)
    context.insert(BodyMeasurement(horse: horse, type: .bodyTemperature, value: 37.6, timestamp: date(2026, 11, 9, 8)))
    try context.save()

    let files = try await CSVExporter(modelContainer: container).makeFiles(
      horseIDs: [horse.id], areas: [.horses, .measurements], interval: nil, format: .excelGerman, calendar: calendar)
    #expect(files.map(\.name) == ["Pferde.csv", "Messwerte.csv"])
    #expect(files.map(\.rowCount) == [1, 1])
    let csv = text(files[1].data)
    #expect(csv.contains(";Lünä;bodyTemperature;37,6;°C;2026-11-09T08:00:00+01:00;"))
  }
}

/// Writes sample CSV files for a manual check in Excel and Numbers when `EQUI_CSV_SAMPLE_DIR` is set
/// (Phase 6 acceptance). Without the variable this test does nothing.
@Suite("CSV-Beispieldateien")
struct CSVSampleFiles {
  @Test("Beispieldateien für Excel/Numbers schreiben")
  func writeSamples() async throws {
    guard let path = ProcessInfo.processInfo.environment["EQUI_CSV_SAMPLE_DIR"] else { return }
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let horse = Horse(name: "Lünä „Süße“")
    horse.breed = "Deutsches Reitpony"
    horse.sex = .mare
    horse.notes = "Frisst gern Äpfel; mag keine \"Möhren\"\nZweite Zeile, mit Komma"
    horse.birthDate = Date(timeIntervalSince1970: 1_400_000_000)
    context.insert(horse)
    let now = Date(timeIntervalSince1970: 1_794_300_000)
    context.insert(BodyMeasurement(horse: horse, type: .weight, value: 540.5, timestamp: now, method: .scale))
    context.insert(
      BodyMeasurement(horse: horse, type: .bodyTemperature, value: 37.8, timestamp: now, method: .thermometer))
    let hay = Feed(name: "Heu (1. Schnitt)", category: .roughage, defaultUnit: .kilogram)
    context.insert(hay)
    horse.applyFeedingPlan(
      [FeedingPlanLine(feedID: hay.id, amount: 8.25, unit: .kilogram, meal: .adLibitum)], from: now, feeds: [hay],
      in: context)
    let treatment = Treatment(horse: horse, kind: .veterinarian, date: now)
    treatment.descriptionText = "Kolik-Untersuchung; Rektale Untersuchung, \"unauffällig\""
    treatment.cost = 120.5
    context.insert(treatment)
    let medication = Medication(treatment: treatment, productName: "Flunixin")
    medication.dose = 12.5
    medication.doseUnit = "ml"
    medication.foodWithdrawalDays = 5
    context.insert(medication)
    try context.save()

    for format in CSVFormat.allCases {
      let folder = URL(filePath: path).appending(path: format.rawValue)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let files = try await CSVExporter(modelContainer: container).makeFiles(
        horseIDs: [horse.id], areas: Set(CSVArea.allCases), interval: nil, format: format)
      for file in files {
        try file.data.write(to: folder.appending(path: file.name))
      }
    }
  }
}

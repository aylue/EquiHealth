import Foundation
import SwiftData

/// Data areas, one CSV file each (F-CSV-01).
public enum CSVArea: String, CaseIterable, Sendable {
  case horses, measurements, feeding, symptoms, conditions, treatments, medications, reminders, training

  public var fileName: String {
    switch self {
    case .horses: "Pferde.csv"
    case .measurements: "Messwerte.csv"
    case .feeding: "Fütterung.csv"
    case .symptoms: "Symptome.csv"
    case .conditions: "Krankheiten.csv"
    case .treatments: "Behandlungen.csv"
    case .medications: "Medikamente.csv"
    case .reminders: "Erinnerungen.csv"
    case .training: "Trainingseinheiten.csv"
    }
  }
}

/// A generated export file.
public struct ExportFile: Sendable, Identifiable {
  public var name: String
  public var data: Data
  /// Number of data rows (without header).
  public var rowCount: Int
  public var id: String { name }
}

/// Builds the CSV tables (F-CSV-01, F-CSV-02, F-BEH-12).
///
/// Column names are German; values of fixed-choice types are their stable raw values (Q-048).
public enum CSVExportBuilder {
  /// - Parameter interval: only entries in this period; `nil` = all. Horses and reminder rules are not
  ///   filtered by time.
  public static func tables(
    horses: [Horse], areas: Set<CSVArea> = Set(CSVArea.allCases), interval: DateInterval? = nil,
    calendar: Calendar = .current
  ) -> [CSVTable] {
    func inRange(_ date: Date?) -> Bool {
      guard let interval else { return true }
      guard let date else { return false }
      return interval.contains(date)
    }
    func overlaps(_ start: Date, _ end: Date?) -> Bool {
      guard let interval else { return true }
      return start < interval.end && (end ?? .distantFuture) >= interval.start
    }
    let sortedHorses = horses.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    var tables: [CSVTable] = []

    for area in CSVArea.allCases where areas.contains(area) {
      switch area {
      case .horses:
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Name", "Rufname", "Geburtsdatum", "Rasse", "Geschlecht", "Farbe", "Abzeichen", "UELN",
              "Chipnummer", "Schlachttier", "Archiviert", "Notizen",
            ],
            rows: sortedHorses.map { horse in
              [
                .text(horse.id.uuidString), .text(horse.name), .text(horse.callName), .day(horse.birthDate),
                .text(horse.breed), .text(horse.sexRaw), .text(horse.color), .text(horse.markings), .text(horse.ueln),
                .text(horse.microchipNumber), .bool(horse.isFoodProducingAnimal), .bool(horse.isArchived),
                .text(horse.notes),
              ]
            }))

      case .measurements:
        let rows = sortedHorses.flatMap { horse in
          (horse.measurements ?? []).filter { inRange($0.timestamp) }.sorted { $0.timestamp < $1.timestamp }
            .map { m -> [CSVValue] in
              [
                .text(m.id.uuidString), .text(horse.name), .text(m.typeRaw), .number(m.value),
                .text(m.type.storageUnitSymbol), .timestamp(m.timestamp), .text(m.methodRaw), .bool(m.isEstimated),
                .text(m.note),
              ]
            }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: ["ID", "Pferd", "Typ", "Wert", "Einheit", "Zeitpunkt", "Methode", "Geschätzt", "Notiz"],
            rows: rows))

      case .feeding:
        var rows: [[CSVValue]] = []
        for horse in sortedHorses {
          for item in (horse.feedingPlanItems ?? []).sorted(by: { $0.validFrom < $1.validFrom })
          where overlaps(item.validFrom, item.validUntil) {
            rows.append([
              .text(item.id.uuidString), .text("plan"), .text(horse.name), .text(item.feed?.name),
              .text(item.feed?.categoryRaw), .number(item.amount), .text(item.unitRaw), .text(item.mealRaw),
              .day(item.validFrom), .day(item.validUntil), .empty, .empty,
            ])
          }
          for log in (horse.feedingLogs ?? []).sorted(by: { $0.timestamp < $1.timestamp }) where inRange(log.timestamp)
          {
            rows.append([
              .text(log.id.uuidString), .text(log.kindRaw), .text(horse.name), .text(log.feed?.name),
              .text(log.feed?.categoryRaw), .number(log.amount), .text(log.unitRaw), .text(log.mealRaw), .empty, .empty,
              .timestamp(log.timestamp), .text(log.note),
            ])
          }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Art", "Pferd", "Futtermittel", "Kategorie", "Menge", "Einheit", "Mahlzeit", "Gültig ab",
              "Gültig bis", "Zeitpunkt", "Notiz",
            ],
            rows: rows))

      case .symptoms:
        let rows = sortedHorses.flatMap { horse in
          (horse.symptoms ?? []).filter { overlaps($0.startDate, $0.endDate) }.sorted { $0.startDate < $1.startDate }
            .map { s -> [CSVValue] in
              let details = s.detailsData.flatMap { String(data: $0, encoding: .utf8) }
              return [
                .text(s.id.uuidString), .text(horse.name), .text(s.categoryRaw), .text(s.customCategoryName),
                .text(s.severityRaw), .timestamp(s.startDate), .timestamp(s.endDate), .text(details),
                .text(s.condition?.name), .text(s.treatment?.id.uuidString), .number((s.attachments ?? []).count),
                .text(s.note),
              ]
            }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Pferd", "Kategorie", "Eigene Kategorie", "Schweregrad", "Beginn", "Ende", "Details (JSON)",
              "Krankheit", "Behandlung (ID)", "Fotos", "Notiz",
            ],
            rows: rows))

      case .conditions:
        let rows = sortedHorses.flatMap { horse in
          (horse.conditions ?? []).filter { overlaps($0.diagnosedAt ?? $0.createdAt, $0.healedAt) }
            .sorted { ($0.diagnosedAt ?? $0.createdAt) < ($1.diagnosedAt ?? $1.createdAt) }
            .map { c -> [CSVValue] in
              [
                .text(c.id.uuidString), .text(horse.name), .text(c.name), .day(c.diagnosedAt), .day(c.healedAt),
                .bool(c.isChronic), .text(c.diagnosedBy), .text(c.note),
              ]
            }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Pferd", "Bezeichnung", "Diagnostiziert am", "Ausgeheilt am", "Chronisch", "Diagnostiziert von",
              "Notiz",
            ],
            rows: rows))

      case .treatments:
        let rows = sortedHorses.flatMap { horse in
          (horse.treatments ?? []).filter { inRange($0.date) }.sorted { $0.date < $1.date }
            .map { t -> [CSVValue] in
              [
                .text(t.id.uuidString), .text(horse.name), .text(t.kindRaw), .text(t.customKindName),
                .timestamp(t.date), .text(t.contact?.name), .text(t.descriptionText), .number(t.cost),
                .text(t.currencyCode), .text(t.condition?.name), .number((t.attachments ?? []).count),
              ]
            }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Pferd", "Art", "Bezeichnung", "Datum", "Dienstleister", "Beschreibung", "Kosten", "Währung",
              "Krankheit", "Anhänge",
            ],
            rows: rows))

      case .medications:
        let rows = sortedHorses.flatMap { horse in
          (horse.treatments ?? []).filter { inRange($0.date) }.sorted { $0.date < $1.date }
            .flatMap { treatment in
              (treatment.medications ?? []).sorted { $0.createdAt < $1.createdAt }.map { m -> [CSVValue] in
                [
                  .text(m.id.uuidString), .text(horse.name), .text(treatment.id.uuidString), .timestamp(treatment.date),
                  .text(m.productName), .text(m.activeIngredient), .number(m.dose), .text(m.doseUnit),
                  .text(m.routeRaw), .day(m.startDate), .day(m.endDate), .text(m.frequency), .text(m.batchNumber),
                  .text(m.vaccinationTargetsRaw.isEmpty ? nil : m.vaccinationTargetsRaw.joined(separator: ", ")),
                  .day(m.withdrawalEnd(.food, calendar: calendar)),
                  .day(m.withdrawalEnd(.competition, calendar: calendar)),
                ]
              }
            }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Pferd", "Behandlung (ID)", "Behandlungsdatum", "Präparat", "Wirkstoff", "Dosis", "Einheit",
              "Verabreichung", "Beginn", "Ende", "Häufigkeit", "Charge", "Impfung gegen",
              "Wartezeit Lebensmittel bis", "Karenzzeit Turnier bis",
            ],
            rows: rows))

      case .reminders:
        let rows = sortedHorses.flatMap { horse in
          (horse.reminderRules ?? []).sorted { $0.title < $1.title }.map { r -> [CSVValue] in
            [
              .text(r.id.uuidString), .text(horse.name), .text(r.title), .text(r.kindRaw), .number(r.intervalValue),
              .text(r.intervalUnitRaw), .number(r.leadTimeDays),
              .text(String(format: "%02d:%02d", r.reminderHour, r.reminderMinute)), .day(r.startDate),
              .bool(r.isActive),
              .day(r.lastFulfilledDate), .day(r.nextDueDate(calendar: calendar)),
            ]
          }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Pferd", "Titel", "Art", "Intervall", "Intervall-Einheit", "Vorlauf (Tage)", "Uhrzeit",
              "Erster Termin", "Aktiv", "Zuletzt erledigt", "Nächste Fälligkeit",
            ],
            rows: rows))

      case .training:
        let rows = sortedHorses.flatMap { horse in
          (horse.trainingSessions ?? []).filter { inRange($0.start) }.sorted { $0.start < $1.start }
            .map { t -> [CSVValue] in
              [
                .text(t.id.uuidString), .text(horse.name), .text(t.typeRaw), .timestamp(t.start), .timestamp(t.end),
                .number(t.duration / 60), .number(t.distance.map { $0 / 1000 }),
                .number(t.walkDuration.map { $0 / 60 }),
                .number(t.trotDuration.map { $0 / 60 }), .number(t.canterDuration.map { $0 / 60 }),
                .number(t.heartRateAverage), .number(t.heartRateMax), .text(t.sourceApp), .text(t.note),
              ]
            }
        }
        tables.append(
          CSVTable(
            fileName: area.fileName,
            header: [
              "ID", "Pferd", "Typ", "Beginn", "Ende", "Dauer (min)", "Distanz (km)", "Schritt (min)", "Trab (min)",
              "Galopp (min)", "Herzfrequenz Ø", "Herzfrequenz max", "Quelle", "Notiz",
            ],
            rows: rows))
      }
    }
    return tables
  }
}

/// Creates CSV files off the main actor (F-CSV-01 to -05, NF-05).
@ModelActor
public actor CSVExporter {
  public func makeFiles(
    horseIDs: Set<UUID>, areas: Set<CSVArea>, interval: DateInterval?, format: CSVFormat,
    calendar: Calendar = .current
  ) throws -> [ExportFile] {
    let horses = try modelContext.fetch(FetchDescriptor<Horse>()).filter { horseIDs.contains($0.id) }
    return CSVExportBuilder.tables(horses: horses, areas: areas, interval: interval, calendar: calendar).map {
      ExportFile(
        name: $0.fileName, data: CSVWriter.data(for: $0, format: format, timeZone: calendar.timeZone),
        rowCount: $0.rows.count)
    }
  }
}

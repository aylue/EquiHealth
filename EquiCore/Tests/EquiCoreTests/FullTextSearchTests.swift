import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Volltextsuche (SPEC 5, Q-029)")
struct FullTextSearchTests {
  private let german = Locale(identifier: "de_DE")
  private let vocabulary = SearchVocabulary(
    symptomCategories: ["cough": "Husten", "colic": "Kolik"], treatmentKinds: ["veterinarian": "Tierarzt"],
    measurementTypes: ["weight": "Gewicht"])

  @Test("Groß-/Kleinschreibung und Akzente egal, alle Wörter müssen vorkommen")
  func matching() {
    let terms = TextSearch.terms(of: "  hÜsten  NACHTS ", locale: german)
    #expect(terms == ["husten", "nachts"])
    #expect(TextSearch.matches(terms, fields: ["Starker Husten", "vor allem nachts"], locale: german))
    #expect(!TextSearch.matches(terms, fields: ["Starker Husten"], locale: german), "Beide Wörter nötig")
    #expect(!TextSearch.matches([], fields: ["egal"], locale: german))
    #expect(TextSearch.matches(["muster"], fields: [nil, "Müsterstraße"], locale: german))
  }

  @Test("Ausschnitt um den Treffer mit Auslassungszeichen")
  func snippet() {
    let text = String(repeating: "a", count: 60) + " Husten seit gestern " + String(repeating: "b", count: 60)
    let snippet = TextSearch.snippet(for: ["husten"], in: [nil, text], radius: 10, locale: german)
    #expect(snippet == "…aaaaaaaaa Husten seit gest…")
    #expect(TextSearch.snippet(for: ["xyz"], in: [text], locale: german) == nil)
    #expect(TextSearch.snippet(for: ["kurz"], in: ["Kurz\nund gut"], locale: german) == "Kurz und gut")
  }

  @Test("Findet Notizen, Symptome, Behandlungen, Medikamente; neueste zuerst; mit Pferd")
  func searchAcrossEntities() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let luna = Horse(name: "Luna")
    luna.notes = "Empfindlich bei Hufschmied"
    let max = Horse(name: "Max")
    context.insert(luna)
    context.insert(max)
    let day = { (d: Int) in Date(timeIntervalSince1970: 1_790_000_000 + Double(d) * 86_400) }

    let cough = SymptomEntry(horse: luna, category: .cough, severity: .mild, startDate: day(1))
    cough.note = "Trockener Husten nach dem Füttern von Heu"
    context.insert(cough)
    let colic = SymptomEntry(horse: max, category: .colic, severity: .severe, startDate: day(5))
    context.insert(colic)
    let vet = Contact(name: "Dr. Weber", role: .veterinarian)
    context.insert(vet)
    let treatment = Treatment(horse: max, kind: .veterinarian, date: day(5))
    treatment.descriptionText = "Rektale Untersuchung"
    treatment.contact = vet
    context.insert(treatment)
    let medication = Medication(treatment: treatment, productName: "Flunixin")
    medication.activeIngredient = "Flunixin-Meglumin"
    context.insert(medication)
    let weight = BodyMeasurement(horse: luna, type: .weight, value: 540, timestamp: day(3))
    weight.note = "Nach dem Heuwechsel gewogen"
    context.insert(weight)
    context.insert(BodyMeasurement(horse: luna, type: .weight, value: 541, timestamp: day(4)))
    try context.save()

    let search = FullTextSearch(modelContainer: container)

    let heu = try await search.search("heu", vocabulary: vocabulary, locale: german)
    #expect(heu.map(\.kind) == [.measurement, .symptom], "Neueste zuerst")
    #expect(heu.first?.title == "Gewicht")
    #expect(heu.last?.horseName == "Luna")
    #expect(heu.last?.snippet?.contains("Heu") == true)

    let husten = try await search.search("HUSTEN", vocabulary: vocabulary, locale: german)
    #expect(husten.map(\.kind) == [.symptom])
    #expect(husten.first?.recordID == cough.id)

    let kolik = try await search.search("Kolik", vocabulary: vocabulary, locale: german)
    #expect(kolik.map(\.kind) == [.symptom], "Kategorie-Bezeichnung wird gefunden")

    let weber = try await search.search("weber untersuchung", vocabulary: vocabulary, locale: german)
    #expect(weber.map(\.kind) == [.treatment])

    let flunixin = try await search.search("meglumin", vocabulary: vocabulary, locale: german)
    #expect(flunixin.map(\.kind) == [.medication])
    #expect(flunixin.first?.recordID == treatment.id, "Medikament öffnet die Behandlung")
    #expect(flunixin.first?.title == "Flunixin")

    let hoof = try await search.search("hufschmied", vocabulary: vocabulary, locale: german)
    #expect(hoof.map(\.kind) == [.horse])

    #expect(try await search.search("   ", locale: german).isEmpty)
    #expect(try await search.search("gibtsnicht", locale: german).isEmpty)
    #expect(try await search.search("540", locale: german).isEmpty, "Messwerte nur über Notizen")
  }

  @Test("Ergebnisse werden begrenzt")
  func limit() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    let horse = Horse(name: "Luna")
    context.insert(horse)
    for index in 0..<30 {
      let symptom = SymptomEntry(horse: horse, category: .other, severity: .mild)
      symptom.note = "Notiz \(index)"
      context.insert(symptom)
    }
    try context.save()
    let hits = try await FullTextSearch(modelContainer: container).search("notiz", limit: 10, locale: german)
    #expect(hits.count == 10)
  }
}

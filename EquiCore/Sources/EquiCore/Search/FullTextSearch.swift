import Foundation
import SwiftData

/// What a search hit points to.
public enum SearchHitKind: String, CaseIterable, Sendable {
  case symptom, condition, treatment, medication, horse, measurement, feeding, training
}

/// One search result (SPEC 5, tab "Suche").
public struct SearchHit: Identifiable, Equatable, Sendable {
  public var kind: SearchHitKind
  /// ID of the record to open. For medications this is the treatment.
  public var recordID: UUID
  public var horseID: UUID?
  public var horseName: String?
  public var title: String
  /// Part of the matching text around the first search term.
  public var snippet: String?
  public var date: Date?

  public var id: String { "\(kind.rawValue).\(recordID.uuidString).\(title)" }
}

/// Localised names of fixed choices; the app passes them in, so EquiCore stays free of UI texts.
public struct SearchVocabulary: Sendable {
  public var symptomCategories: [String: String]
  public var treatmentKinds: [String: String]
  public var measurementTypes: [String: String]
  public var trainingTypes: [String: String]

  public init(
    symptomCategories: [String: String] = [:], treatmentKinds: [String: String] = [:],
    measurementTypes: [String: String] = [:], trainingTypes: [String: String] = [:]
  ) {
    self.symptomCategories = symptomCategories
    self.treatmentKinds = treatmentKinds
    self.measurementTypes = measurementTypes
    self.trainingTypes = trainingTypes
  }
}

/// Text matching for the search: case and diacritic insensitive, every term must occur (AND).
public enum TextSearch {
  /// Lowercased, without diacritics, in the given locale.
  public static func normalize(_ text: String, locale: Locale = .current) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: locale)
  }

  /// Search terms of a query; empty for blank input.
  public static func terms(of query: String, locale: Locale = .current) -> [String] {
    normalize(query, locale: locale).split(whereSeparator: \.isWhitespace).map(String.init)
  }

  /// Whether every term occurs in at least one of the fields.
  public static func matches(_ terms: [String], fields: [String?], locale: Locale = .current) -> Bool {
    guard !terms.isEmpty else { return false }
    let normalized = fields.compactMap { $0 }.map { normalize($0, locale: locale) }
    return terms.allSatisfy { term in normalized.contains { $0.contains(term) } }
  }

  /// About `radius` characters before and after the first occurrence of a term, with ellipses.
  public static func snippet(
    for terms: [String], in fields: [String?], radius: Int = 40, locale: Locale = .current
  ) -> String? {
    for field in fields.compactMap({ $0 }) where !field.isEmpty {
      let normalized = normalize(field, locale: locale)
      // Folding keeps the character count for the Latin texts used here; fall back to the start.
      guard let term = terms.first(where: { normalized.contains($0) }),
        let range = normalized.range(of: term), normalized.count == field.count
      else { continue }
      let offset = normalized.distance(from: normalized.startIndex, to: range.lowerBound)
      let start = max(0, offset - radius)
      let end = min(field.count, offset + term.count + radius)
      let lower = field.index(field.startIndex, offsetBy: start)
      let upper = field.index(field.startIndex, offsetBy: end)
      let text = field[lower..<upper].replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespaces)
      return (start > 0 ? "…" : "") + text + (end < field.count ? "…" : "")
    }
    return nil
  }
}

/// Searches notes, symptoms, conditions, treatments, medications and more, off the main actor
/// (SPEC 5, NF-05). Results are sorted by date, newest first, at most `limit`.
@ModelActor
public actor FullTextSearch {
  public func search(
    _ query: String, vocabulary: SearchVocabulary = SearchVocabulary(), limit: Int = 200,
    locale: Locale = .current
  ) throws -> [SearchHit] {
    let terms = TextSearch.terms(of: query, locale: locale)
    guard !terms.isEmpty else { return [] }
    var hits: [SearchHit] = []

    func check(
      _ kind: SearchHitKind, id: UUID, horse: Horse?, title: String, date: Date?, fields: [String?]
    ) {
      guard TextSearch.matches(terms, fields: [title] + fields, locale: locale) else { return }
      hits.append(
        SearchHit(
          kind: kind, recordID: id, horseID: horse?.id, horseName: horse?.name, title: title,
          snippet: TextSearch.snippet(for: terms, in: fields, locale: locale), date: date))
    }

    for symptom in try modelContext.fetch(FetchDescriptor<SymptomEntry>()) {
      let category = vocabulary.symptomCategories[symptom.categoryRaw] ?? symptom.categoryRaw
      let title = symptom.customCategoryName ?? category
      check(
        .symptom, id: symptom.id, horse: symptom.horse, title: title, date: symptom.startDate,
        fields: [symptom.note, category, symptom.condition?.name])
    }
    for condition in try modelContext.fetch(FetchDescriptor<Condition>()) {
      check(
        .condition, id: condition.id, horse: condition.horse, title: condition.name,
        date: condition.diagnosedAt ?? condition.createdAt, fields: [condition.note, condition.diagnosedBy])
    }
    for treatment in try modelContext.fetch(FetchDescriptor<Treatment>()) {
      let kind = vocabulary.treatmentKinds[treatment.kindRaw] ?? treatment.kindRaw
      check(
        .treatment, id: treatment.id, horse: treatment.horse, title: treatment.customKindName ?? kind,
        date: treatment.date,
        fields: [
          treatment.descriptionText, kind, treatment.contact?.name, treatment.contact?.practice,
          treatment.condition?.name,
        ])
    }
    for medication in try modelContext.fetch(FetchDescriptor<Medication>()) {
      guard let treatment = medication.treatment else { continue }
      check(
        .medication, id: treatment.id, horse: treatment.horse, title: medication.productName, date: treatment.date,
        fields: [
          medication.activeIngredient, medication.batchNumber, medication.frequency,
          medication.customVaccinationTarget,
        ])
    }
    for horse in try modelContext.fetch(FetchDescriptor<Horse>()) {
      check(
        .horse, id: horse.id, horse: horse, title: horse.name, date: nil,
        fields: [horse.notes, horse.callName, horse.breed, horse.ueln, horse.microchipNumber])
    }
    // Free-text notes of other entries: only the note is searched, not names or types.
    for measurement in try modelContext.fetch(
      FetchDescriptor<BodyMeasurement>(predicate: #Predicate { $0.note != "" }))
    {
      let title = vocabulary.measurementTypes[measurement.typeRaw] ?? measurement.typeRaw
      guard TextSearch.matches(terms, fields: [measurement.note], locale: locale) else { continue }
      hits.append(
        SearchHit(
          kind: .measurement, recordID: measurement.id, horseID: measurement.horse?.id,
          horseName: measurement.horse?.name, title: title,
          snippet: TextSearch.snippet(for: terms, in: [measurement.note], locale: locale), date: measurement.timestamp))
    }
    for log in try modelContext.fetch(FetchDescriptor<FeedingLog>(predicate: #Predicate { $0.note != "" })) {
      guard TextSearch.matches(terms, fields: [log.note], locale: locale) else { continue }
      hits.append(
        SearchHit(
          kind: .feeding, recordID: log.id, horseID: log.horse?.id, horseName: log.horse?.name,
          title: log.feed?.name ?? "", snippet: TextSearch.snippet(for: terms, in: [log.note], locale: locale),
          date: log.timestamp))
    }
    for session in try modelContext.fetch(FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.note != "" })) {
      guard TextSearch.matches(terms, fields: [session.note], locale: locale) else { continue }
      hits.append(
        SearchHit(
          kind: .training, recordID: session.id, horseID: session.horse?.id, horseName: session.horse?.name,
          title: vocabulary.trainingTypes[session.typeRaw] ?? session.typeRaw,
          snippet: TextSearch.snippet(for: terms, in: [session.note], locale: locale), date: session.start))
    }

    hits.sort { ($0.date ?? .distantPast, $0.title) > ($1.date ?? .distantPast, $1.title) }
    return Array(hits.prefix(limit))
  }
}

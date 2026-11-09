import Foundation
import SwiftData

extension EquiSchemaV1 {
  /// An observed symptom (F-GESUND-01).
  @Model
  public final class SymptomEntry: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var categoryRaw: String = SymptomCategory.other.rawValue
    /// Name of a user-defined category when `category == .custom` (F-GESUND-02).
    public var customCategoryName: String?
    public var severityRaw: String = Severity.mild.rawValue
    public var startDate: Date = Date()
    /// `nil` = ongoing (F-GESUND-03).
    public var endDate: Date?
    /// JSON-encoded `SymptomDetails`. Small, therefore not external storage.
    // ANNAHME: Details als JSON-Data statt als SwiftData-Composite gespeichert, damit optionale
    // verschachtelte Structs CloudKit-sicher und migrationsstabil bleiben. Siehe OPEN_QUESTIONS.md.
    public var detailsData: Data?
    public var note: String = ""

    public var horse: Horse?
    public var condition: Condition?
    public var treatment: Treatment?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.symptom)
    public var attachments: [Attachment]? = []

    public var category: SymptomCategory {
      get { SymptomCategory(rawValue: categoryRaw) ?? .other }
      set { categoryRaw = newValue.rawValue }
    }

    public var severity: Severity {
      get { Severity(rawValue: severityRaw) ?? .mild }
      set { severityRaw = newValue.rawValue }
    }

    public var isOngoing: Bool { endDate == nil }

    public var details: SymptomDetails {
      get {
        guard let detailsData else { return SymptomDetails() }
        return (try? JSONDecoder().decode(SymptomDetails.self, from: detailsData)) ?? SymptomDetails()
      }
      set {
        detailsData = newValue == SymptomDetails() ? nil : try? JSONEncoder().encode(newValue)
      }
    }

    public init(horse: Horse?, category: SymptomCategory, severity: Severity, startDate: Date = .now) {
      self.horse = horse
      self.categoryRaw = category.rawValue
      self.severityRaw = severity.rawValue
      self.startDate = startDate
    }
  }

  /// A disease or diagnosis (F-GESUND-04).
  @Model
  public final class Condition: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var name: String = ""
    public var diagnosedAt: Date?
    public var healedAt: Date?
    public var isChronic: Bool = false
    public var diagnosedBy: String?
    public var note: String = ""

    public var horse: Horse?

    @Relationship(deleteRule: .nullify, inverse: \SymptomEntry.condition)
    public var symptoms: [SymptomEntry]? = []
    @Relationship(deleteRule: .nullify, inverse: \Treatment.condition)
    public var treatments: [Treatment]? = []

    public init(horse: Horse?, name: String, diagnosedAt: Date? = nil, isChronic: Bool = false) {
      self.horse = horse
      self.name = name
      self.diagnosedAt = diagnosedAt
      self.isChronic = isChronic
    }
  }
}

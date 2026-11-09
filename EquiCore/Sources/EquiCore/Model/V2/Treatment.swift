import Foundation
import SwiftData

extension EquiSchemaV2 {
  /// An appointment or treatment (F-BEH-01, F-BEH-02).
  @Model
  public final class Treatment: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var kindRaw: String = TreatmentKind.other.rawValue
    /// Free name when `kind == .other` (F-BEH-02).
    public var customKindName: String?
    public var date: Date = Date()
    public var descriptionText: String = ""
    /// Optional cost (F-BEH-07, KANN).
    public var cost: Double?
    public var currencyCode: String?

    public var horse: Horse?
    public var contact: Contact?
    public var condition: Condition?

    @Relationship(deleteRule: .cascade, inverse: \Medication.treatment)
    public var medications: [Medication]? = []
    @Relationship(deleteRule: .cascade, inverse: \Attachment.treatment)
    public var attachments: [Attachment]? = []
    @Relationship(deleteRule: .nullify, inverse: \SymptomEntry.treatment)
    public var symptoms: [SymptomEntry]? = []

    public var kind: TreatmentKind {
      get { TreatmentKind(rawValue: kindRaw) ?? .other }
      set { kindRaw = newValue.rawValue }
    }

    public init(horse: Horse?, kind: TreatmentKind, date: Date = .now) {
      self.horse = horse
      self.kindRaw = kind.rawValue
      self.date = date
    }
  }

  /// An administered medication or vaccine (F-BEH-03, F-BEH-04, F-BEH-08).
  /// Withdrawal periods are user input only; the app never supplies its own values.
  @Model
  public final class Medication: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var productName: String = ""
    public var activeIngredient: String?
    public var dose: Double?
    public var doseUnit: String?
    public var routeRaw: String?
    public var startDate: Date?
    public var endDate: Date?
    public var frequency: String?
    public var batchNumber: String?
    /// Food withdrawal period end ("Wartezeit Lebensmittel bis").
    public var foodWithdrawalUntil: Date?
    /// Food withdrawal entered as days after the last dose (F-BEH-08).
    public var foodWithdrawalDays: Int?
    /// Competition withdrawal end ("Karenzzeit Turnier bis").
    public var competitionWithdrawalUntil: Date?
    /// Competition withdrawal entered as days after the last dose (F-BEH-08).
    public var competitionWithdrawalDays: Int?
    /// Raw values of `VaccinationTarget` (F-BEH-04).
    public var vaccinationTargetsRaw: [String] = []
    public var customVaccinationTarget: String?

    public var treatment: Treatment?

    public var route: AdministrationRoute? {
      get { routeRaw.flatMap(AdministrationRoute.init(rawValue:)) }
      set { routeRaw = newValue?.rawValue }
    }

    public var vaccinationTargets: [VaccinationTarget] {
      get { vaccinationTargetsRaw.compactMap(VaccinationTarget.init(rawValue:)) }
      set { vaccinationTargetsRaw = newValue.map(\.rawValue) }
    }

    public init(treatment: Treatment?, productName: String) {
      self.treatment = treatment
      self.productName = productName
    }
  }

  /// A reusable contact such as a veterinarian or farrier (F-BEH-05). Shared master data (F-TEIL-01).
  @Model
  public final class Contact: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var name: String = ""
    public var roleRaw: String = ContactRole.other.rawValue
    public var practice: String?
    public var phone: String?
    public var email: String?
    public var address: String?

    @Relationship(deleteRule: .nullify, inverse: \Treatment.contact)
    public var treatments: [Treatment]? = []

    public var role: ContactRole {
      get { ContactRole(rawValue: roleRaw) ?? .other }
      set { roleRaw = newValue.rawValue }
    }

    public init(name: String, role: ContactRole) {
      self.name = name
      self.roleRaw = role.rawValue
    }
  }
}

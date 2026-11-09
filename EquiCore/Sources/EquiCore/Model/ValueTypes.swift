import Foundation

// Fixed-choice types. They are persisted as their `String` raw value (SPEC section 3) so that
// export formats and migrations stay stable. Never rename an existing raw value.

/// Sex of a horse (Stute/Wallach/Hengst).
public enum HorseSex: String, CaseIterable, Codable, Sendable {
  case mare
  case gelding
  case stallion
}

/// Kind of a body measurement (F-MESS-01, F-MESS-06).
public enum MeasurementType: String, CaseIterable, Codable, Sendable {
  case weight
  case heightAtWithers
  case bellyGirth
  case chestGirth
  case bodyLength
  case bodyTemperature
  case pulse
  case respiratoryRate
  case bodyConditionScore

  /// SI (or dimensionless) unit symbol the value is stored in (F-ARCH-04).
  public var storageUnitSymbol: String {
    switch self {
    case .weight: "kg"
    case .heightAtWithers, .bellyGirth, .chestGirth, .bodyLength: "cm"
    case .bodyTemperature: "°C"
    case .pulse, .respiratoryRate: "1/min"
    case .bodyConditionScore: ""
    }
  }
}

/// How a measurement was taken.
public enum MeasurementMethod: String, CaseIterable, Codable, Sendable {
  case scale
  case measuringTape
  case estimationFormula
  case thermometer
  // ANNAHME: "other" ergänzt für Puls, Atemfrequenz und BCS, die keine der vier Methoden nutzen.
  case other
}

/// Category of a feed (F-FUTTER-01).
public enum FeedCategory: String, CaseIterable, Codable, Sendable {
  case roughage
  case concentrate
  case mineral
  case supplement
  case succulent
  case other
}

/// Unit of a feed amount (F-FUTTER-02).
// ANNAHME: Futtermengen werden in der gewählten Einheit gespeichert, da Messbecher und Scheiben
// nicht in SI umrechenbar sind (Ausnahme zu F-ARCH-04). Siehe OPEN_QUESTIONS.md.
public enum FeedUnit: String, CaseIterable, Codable, Sendable {
  case kilogram
  case gram
  case liter
  case scoop
  case flake
}

/// Meal slot of a feeding plan item.
public enum Meal: String, CaseIterable, Codable, Sendable {
  case morning
  case noon
  case evening
  case adLibitum
}

/// Built-in symptom categories (F-GESUND-01). `custom` uses `SymptomEntry.customCategoryName` (F-GESUND-02).
public enum SymptomCategory: String, CaseIterable, Codable, Sendable {
  case cough
  case muscleStiffness
  case colic
  case eyeInflammation
  case lameness
  case diarrhea
  case skinChange
  case fever
  case other
  case custom
}

/// Severity of a symptom.
public enum Severity: String, CaseIterable, Codable, Sendable {
  case mild
  case moderate
  case severe
}

/// Kind of a treatment or appointment (F-BEH-02).
public enum TreatmentKind: String, CaseIterable, Codable, Sendable {
  case veterinarian
  case vaccination
  case dental
  case farrier
  case osteopathy
  case physiotherapy
  case deworming
  case other
}

/// Disease a vaccination protects against (F-BEH-04).
public enum VaccinationTarget: String, CaseIterable, Codable, Sendable {
  case influenza
  case tetanus
  case herpes
  case rabies
  case other
}

/// Route of administration of a medication.
public enum AdministrationRoute: String, CaseIterable, Codable, Sendable {
  case oral
  case intramuscular
  case intravenous
  case subcutaneous
  case topical
  case inhalation
  case other
}

/// Role of a contact (F-BEH-05).
public enum ContactRole: String, CaseIterable, Codable, Sendable {
  case veterinarian
  case farrier
  case dentist
  case osteopath
  case physiotherapist
  case other
}

/// Kind of a reminder rule (F-ERIN-01, F-ERIN-03).
public enum ReminderKind: String, CaseIterable, Codable, Sendable {
  case vaccinationInfluenza
  case vaccinationTetanus
  case vaccinationHerpes
  case dentalCheck
  case farrier
  case deworming
  case custom
}

/// Calendar unit of a reminder interval.
public enum IntervalUnit: String, CaseIterable, Codable, Sendable {
  case days
  case weeks
  case months
  case years
}

/// Type of a training session written by the training app (F-TRAIN-03).
public enum TrainingType: String, CaseIterable, Codable, Sendable {
  case riding
  case dressage
  case jumping
  case hacking
  case lunging
  case groundwork
  case other
}

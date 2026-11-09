import EquiCore
import Foundation

extension HorseSex {
  nonisolated var title: String {
    switch self {
    case .mare: String(localized: "Stute")
    case .gelding: String(localized: "Wallach")
    case .stallion: String(localized: "Hengst")
    }
  }
}

extension MeasurementMethod {
  nonisolated var title: String {
    switch self {
    case .scale: String(localized: "Waage")
    case .measuringTape: String(localized: "Maßband")
    case .estimationFormula: String(localized: "Schätzformel")
    case .thermometer: String(localized: "Thermometer")
    case .other: String(localized: "Sonstige")
    }
  }
}

extension ChartTimeRange {
  /// Segment label like in Apple Health.
  nonisolated var shortTitle: String {
    switch self {
    case .day: String(localized: "T", comment: "Chart range: day")
    case .week: String(localized: "W", comment: "Chart range: week")
    case .month: String(localized: "M", comment: "Chart range: month")
    case .sixMonths: String(localized: "6M", comment: "Chart range: six months")
    case .year: String(localized: "J", comment: "Chart range: year")
    case .all: String(localized: "Alle", comment: "Chart range: all")
    }
  }

  nonisolated var accessibilityTitle: String {
    switch self {
    case .day: String(localized: "Tag")
    case .week: String(localized: "Woche")
    case .month: String(localized: "Monat")
    case .sixMonths: String(localized: "Sechs Monate")
    case .year: String(localized: "Jahr")
    case .all: String(localized: "Alle")
    }
  }
}

extension SymptomCategory {
  nonisolated var title: String {
    switch self {
    case .cough: String(localized: "Husten")
    case .muscleStiffness: String(localized: "Spannigkeit")
    case .colic: String(localized: "Kolik")
    case .eyeInflammation: String(localized: "Augenentzündung")
    case .lameness: String(localized: "Lahmheit")
    case .diarrhea: String(localized: "Durchfall")
    case .skinChange: String(localized: "Hautveränderung")
    case .fever: String(localized: "Fieber")
    case .other: String(localized: "Sonstiges")
    case .custom: String(localized: "Eigene Kategorie")
    }
  }

  nonisolated var systemImage: String {
    switch self {
    case .cough: "wind"
    case .muscleStiffness: "figure.flexibility"
    case .colic: "exclamationmark.octagon"
    case .eyeInflammation: "eye"
    case .lameness: "figure.walk.motion"
    case .diarrhea: "drop.triangle"
    case .skinChange: "allergens"
    case .fever: "thermometer.high"
    case .other: "cross.case"
    case .custom: "tag"
    }
  }
}

extension SymptomEntry {
  /// Category name including user-defined categories (F-GESUND-02).
  var categoryTitle: String {
    if category == .custom, let customCategoryName { return customCategoryName }
    return category.title
  }
}

extension Severity {
  nonisolated var title: String {
    switch self {
    case .mild: String(localized: "leicht")
    case .moderate: String(localized: "mittel")
    case .severe: String(localized: "schwer")
    }
  }
}

extension TreatmentKind {
  nonisolated var title: String {
    switch self {
    case .veterinarian: String(localized: "Tierarztbesuch")
    case .vaccination: String(localized: "Impfung")
    case .dental: String(localized: "Zahnbehandlung")
    case .farrier: String(localized: "Hufschmied")
    case .osteopathy: String(localized: "Osteopathie")
    case .physiotherapy: String(localized: "Physiotherapie")
    case .deworming: String(localized: "Wurmkur")
    case .other: String(localized: "Sonstige")
    }
  }

  nonisolated var systemImage: String {
    switch self {
    case .veterinarian: "stethoscope"
    case .vaccination: "syringe"
    case .dental: "mouth"
    case .farrier: "hammer"
    case .osteopathy: "hand.raised"
    case .physiotherapy: "figure.cooldown"
    case .deworming: "pills"
    case .other: "cross.case"
    }
  }
}

extension Treatment {
  /// Kind name including free names for `.other` (F-BEH-02).
  var kindTitle: String {
    if kind == .other, let customKindName { return customKindName }
    return kind.title
  }
}

extension VaccinationTarget {
  nonisolated var title: String {
    switch self {
    case .influenza: String(localized: "Influenza")
    case .tetanus: String(localized: "Tetanus")
    case .herpes: String(localized: "Herpes")
    case .rabies: String(localized: "Tollwut")
    case .other: String(localized: "Sonstige")
    }
  }
}

extension AdministrationRoute {
  nonisolated var title: String {
    switch self {
    case .oral: String(localized: "oral")
    case .intramuscular: String(localized: "intramuskulär")
    case .intravenous: String(localized: "intravenös")
    case .subcutaneous: String(localized: "subkutan")
    case .topical: String(localized: "äußerlich")
    case .inhalation: String(localized: "Inhalation")
    case .other: String(localized: "sonstige")
    }
  }
}

extension ContactRole {
  nonisolated var title: String {
    switch self {
    case .veterinarian: String(localized: "Tierarzt")
    case .farrier: String(localized: "Hufschmied")
    case .dentist: String(localized: "Pferdezahnarzt")
    case .osteopath: String(localized: "Osteopath")
    case .physiotherapist: String(localized: "Physiotherapeut")
    case .other: String(localized: "Sonstige")
    }
  }
}

extension WithdrawalKind {
  nonisolated var title: String {
    switch self {
    case .food: String(localized: "Wartezeit Lebensmittel")
    case .competition: String(localized: "Turnier-Karenzzeit")
    }
  }
}

extension TimelineKind {
  nonisolated var title: String {
    switch self {
    case .symptom: String(localized: "Symptome")
    case .condition: String(localized: "Krankheiten")
    case .treatment: String(localized: "Behandlungen")
    }
  }
}

extension FeedCategory {
  nonisolated var title: String {
    switch self {
    case .roughage: String(localized: "Raufutter")
    case .concentrate: String(localized: "Kraftfutter")
    case .mineral: String(localized: "Mineralfutter")
    case .supplement: String(localized: "Ergänzungsfutter")
    case .succulent: String(localized: "Saftfutter")
    case .other: String(localized: "Sonstiges")
    }
  }

  nonisolated var systemImage: String {
    switch self {
    case .roughage: "leaf"
    case .concentrate: "circle.grid.cross"
    case .mineral: "cube"
    case .supplement: "plus.circle"
    case .succulent: "carrot"
    case .other: "ellipsis.circle"
    }
  }
}

extension FeedUnit {
  /// Short unit label for amounts, e.g. "8 kg" or "2 Scheiben".
  nonisolated var symbol: String {
    switch self {
    case .kilogram: String(localized: "kg")
    case .gram: String(localized: "g")
    case .liter: String(localized: "l")
    case .scoop: String(localized: "Messbecher")
    case .flake: String(localized: "Scheiben")
    }
  }

  nonisolated var title: String {
    switch self {
    case .kilogram: String(localized: "Kilogramm")
    case .gram: String(localized: "Gramm")
    case .liter: String(localized: "Liter")
    case .scoop: String(localized: "Messbecher")
    case .flake: String(localized: "Scheiben")
    }
  }

  /// "8 kg", "0,5 l", "2 Scheiben".
  nonisolated func format(_ amount: Double) -> String {
    "\(amount.formatted(.number.precision(.fractionLength(0...2)))) \(symbol)"
  }
}

extension Meal {
  nonisolated var title: String {
    switch self {
    case .morning: String(localized: "Morgens")
    case .noon: String(localized: "Mittags")
    case .evening: String(localized: "Abends")
    case .adLibitum: String(localized: "Ad libitum")
    }
  }
}

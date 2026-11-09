import EquiCore
import Foundation

extension HorseSex {
  var title: String {
    switch self {
    case .mare: String(localized: "Stute")
    case .gelding: String(localized: "Wallach")
    case .stallion: String(localized: "Hengst")
    }
  }
}

extension MeasurementMethod {
  var title: String {
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
  var shortTitle: String {
    switch self {
    case .day: String(localized: "T", comment: "Chart range: day")
    case .week: String(localized: "W", comment: "Chart range: week")
    case .month: String(localized: "M", comment: "Chart range: month")
    case .sixMonths: String(localized: "6M", comment: "Chart range: six months")
    case .year: String(localized: "J", comment: "Chart range: year")
    case .all: String(localized: "Alle", comment: "Chart range: all")
    }
  }

  var accessibilityTitle: String {
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

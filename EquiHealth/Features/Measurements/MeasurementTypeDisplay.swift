import EquiCore
import Foundation
import SwiftUI

/// Display information for measurement types. Values are stored in SI units (F-ARCH-04) and
/// formatted with `Foundation.Measurement`.
extension MeasurementType {
  var title: String {
    switch self {
    case .weight: String(localized: "Gewicht")
    case .heightAtWithers: String(localized: "Stockmaß")
    case .bellyGirth: String(localized: "Bauchumfang")
    case .chestGirth: String(localized: "Brustumfang")
    case .bodyLength: String(localized: "Körperlänge")
    case .bodyTemperature: String(localized: "Körpertemperatur")
    case .pulse: String(localized: "Puls")
    case .respiratoryRate: String(localized: "Atemfrequenz")
    case .bodyConditionScore: String(localized: "Body Condition Score")
    }
  }

  var systemImage: String {
    switch self {
    case .weight: "scalemass"
    case .heightAtWithers: "ruler"
    case .bellyGirth: "circle.dashed"
    case .chestGirth: "lasso"
    case .bodyLength: "arrow.left.and.right"
    case .bodyTemperature: "thermometer.medium"
    case .pulse: "heart"
    case .respiratoryRate: "lungs"
    case .bodyConditionScore: "star.leadinghalf.filled"
    }
  }

  /// Unit shown next to the input field.
  var inputUnitLabel: String {
    switch self {
    case .pulse: String(localized: "Schläge/min")
    case .respiratoryRate: String(localized: "Atemzüge/min")
    case .bodyConditionScore: ""
    default: storageUnitSymbol
    }
  }

  private var numberStyle: FloatingPointFormatStyle<Double> {
    switch self {
    case .weight, .pulse, .respiratoryRate: .number.precision(.fractionLength(0))
    case .bodyTemperature: .number.precision(.fractionLength(1))
    case .heightAtWithers, .bellyGirth, .chestGirth, .bodyLength, .bodyConditionScore:
      .number.precision(.fractionLength(0...1))
    }
  }

  // ANNAHME: Eingabe und Anzeige erfolgen metrisch (kg, cm, °C), auch in Regionen mit anderen
  // Einheiten. Regionsabhängige Umrechnung folgt bei der Lokalisierung (Phase 9). Q-016.
  func format(_ value: Double) -> String {
    switch self {
    case .weight:
      Measurement(value: value, unit: UnitMass.kilograms)
        .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: numberStyle))
    case .heightAtWithers, .bellyGirth, .chestGirth, .bodyLength:
      Measurement(value: value, unit: UnitLength.centimeters)
        .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: numberStyle))
    case .bodyTemperature:
      Measurement(value: value, unit: UnitTemperature.celsius)
        .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: numberStyle))
    case .pulse, .respiratoryRate:
      String(localized: "\(value.formatted(numberStyle)) /min")
    case .bodyConditionScore:
      value.formatted(numberStyle)
    }
  }

  /// Plain number for prefilling an input field.
  func inputText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
  }
}

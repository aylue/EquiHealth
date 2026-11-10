import EquiCore
import SwiftUI

extension TrainingType {
  var title: String {
    switch self {
    case .riding: String(localized: "Reiten")
    case .dressage: String(localized: "Dressur")
    case .jumping: String(localized: "Springen")
    case .hacking: String(localized: "Ausritt")
    case .lunging: String(localized: "Longieren")
    case .groundwork: String(localized: "Bodenarbeit")
    case .other: String(localized: "Sonstiges")
    }
  }

  var systemImage: String {
    switch self {
    case .riding, .dressage: "figure.equestrian.sports"
    case .jumping: "arrow.up.forward"
    case .hacking: "map"
    case .lunging: "arrow.trianglehead.2.clockwise.rotate.90"
    case .groundwork: "figure.walk"
    case .other: "ellipsis.circle"
    }
  }
}

extension Gait {
  var title: String {
    switch self {
    case .walk: String(localized: "Schritt")
    case .trot: String(localized: "Trab")
    case .canter: String(localized: "Galopp")
    }
  }
}

enum TrainingFormat {
  /// "1 h 05 min" / "45 min"
  static func duration(_ seconds: Double) -> String {
    Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
  }

  /// "5,2 km"
  static func distance(_ meters: Double) -> String {
    Measurement(value: meters / 1000, unit: UnitLength.kilometers)
      .formatted(
        .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
  }

  /// "112 S/min"
  static func heartRate(_ bpm: Double) -> String {
    String(localized: "\(Int(bpm.rounded())) S/min")
  }
}

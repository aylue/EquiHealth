import EquiCore
import Foundation
import Observation
import SwiftData

/// App-wide UI state that survives restarts (F-PFERD-02) plus the currently presented sheet.
@Observable
final class AppState {
  @ObservationIgnored private let defaults: UserDefaults

  /// The active horse; resolved against the stored horses with `ActiveHorseSelection` (F-PFERD-02).
  var activeHorseID: UUID? {
    didSet { defaults.set(activeHorseID?.uuidString, forKey: Keys.activeHorseID) }
  }

  var hasCompletedOnboarding: Bool {
    didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboardingCompleted) }
  }

  /// Measurement types pinned to the overview.
  var pinnedMeasurementTypes: [MeasurementType] {
    didSet { defaults.set(pinnedMeasurementTypes.map(\.rawValue), forKey: Keys.pinnedTypes) }
  }

  /// Sheet presented above the tab view.
  var sheet: AppSheet?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    activeHorseID = defaults.string(forKey: Keys.activeHorseID).flatMap(UUID.init(uuidString:))
    hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingCompleted)
    if let raw = defaults.stringArray(forKey: Keys.pinnedTypes) {
      pinnedMeasurementTypes = raw.compactMap(MeasurementType.init(rawValue:))
    } else {
      pinnedMeasurementTypes = [.weight, .bodyTemperature]
    }
  }

  // MARK: Legacy reference ranges (Q-015)

  /// One-time import of reference ranges that builds before schema V2 kept in UserDefaults.
  /// Existing values in the data model win; the old keys are removed afterwards.
  func migrateLegacyReferenceRanges(of horses: [Horse], in context: ModelContext) {
    var changed = false
    for horse in horses {
      for type in MeasurementType.allCases {
        let key = Keys.legacyReferenceRange(type, horse.id)
        guard let data = defaults.data(forKey: key) else { continue }
        if horse.referenceRange(for: type) == nil,
          let range = try? JSONDecoder().decode(ReferenceRange.self, from: data)
        {
          horse.setReferenceRange(range, for: type, in: context)
          changed = true
        }
        defaults.removeObject(forKey: key)
      }
    }
    if changed { try? context.save() }
  }

  private enum Keys {
    static let activeHorseID = "activeHorseID"
    static let onboardingCompleted = "onboardingCompleted"
    static let pinnedTypes = "pinnedMeasurementTypes"
    static func legacyReferenceRange(_ type: MeasurementType, _ horseID: UUID) -> String {
      "referenceRange.\(horseID.uuidString).\(type.rawValue)"
    }
  }
}

/// Sheets that can be opened from anywhere (toolbar, "+" menu, empty states).
enum AppSheet: Identifiable, Hashable {
  case newMeasurement(MeasurementType)
  case estimateWeight
  case newSymptom
  case newCondition
  case newTreatment
  case newHorse
  case horseProfile
  case horseManagement
  case stables
  case contacts
  case settings
  case onboarding

  var id: String {
    switch self {
    case .newMeasurement(let type): "newMeasurement.\(type.rawValue)"
    case .estimateWeight: "estimateWeight"
    case .newSymptom: "newSymptom"
    case .newCondition: "newCondition"
    case .newTreatment: "newTreatment"
    case .newHorse: "newHorse"
    case .horseProfile: "horseProfile"
    case .horseManagement: "horseManagement"
    case .stables: "stables"
    case .contacts: "contacts"
    case .settings: "settings"
    case .onboarding: "onboarding"
    }
  }
}

import EquiCore
import Foundation
import Observation

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

  /// Bumped on every reference range change so that views observing ranges refresh.
  private var referenceRangeRevision = 0

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

  // MARK: Reference ranges (F-MESS-04)

  // ANNAHME: Referenzbereiche sind Geräte-Einstellungen pro Pferd und Messtyp (UserDefaults),
  // kein Teil des synchronisierten Datenmodells. Siehe OPEN_QUESTIONS.md (Q-015).
  func referenceRange(for type: MeasurementType, horseID: UUID) -> ReferenceRange? {
    _ = referenceRangeRevision
    guard let data = defaults.data(forKey: Keys.referenceRange(type, horseID)) else { return nil }
    return try? JSONDecoder().decode(ReferenceRange.self, from: data)
  }

  func setReferenceRange(_ range: ReferenceRange?, for type: MeasurementType, horseID: UUID) {
    let key = Keys.referenceRange(type, horseID)
    if let range, let data = try? JSONEncoder().encode(range) {
      defaults.set(data, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
    referenceRangeRevision += 1
  }

  private enum Keys {
    static let activeHorseID = "activeHorseID"
    static let onboardingCompleted = "onboardingCompleted"
    static let pinnedTypes = "pinnedMeasurementTypes"
    static func referenceRange(_ type: MeasurementType, _ horseID: UUID) -> String {
      "referenceRange.\(horseID.uuidString).\(type.rawValue)"
    }
  }
}

/// Sheets that can be opened from anywhere (toolbar, "+" menu, empty states).
enum AppSheet: Identifiable, Hashable {
  case newMeasurement(MeasurementType)
  case estimateWeight
  case newHorse
  case horseProfile
  case horseManagement
  case stables
  case settings
  case onboarding

  var id: String {
    switch self {
    case .newMeasurement(let type): "newMeasurement.\(type.rawValue)"
    case .estimateWeight: "estimateWeight"
    case .newHorse: "newHorse"
    case .horseProfile: "horseProfile"
    case .horseManagement: "horseManagement"
    case .stables: "stables"
    case .settings: "settings"
    case .onboarding: "onboarding"
    }
  }
}

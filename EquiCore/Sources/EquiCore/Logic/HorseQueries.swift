import Foundation
import SwiftData

extension Horse {
  /// Stable assignment valid at `date` (F-PFERD-04, F-WETTER-02).
  public func stableAssignment(at date: Date = .now) -> StableAssignment? {
    (stableAssignments ?? [])
      .filter { $0.validFrom <= date && ($0.validUntil.map { date < $0 } ?? true) }
      .max { $0.validFrom < $1.validFrom }
  }

  /// Moves the horse to `stable` on `date`: ends every assignment still open at that date and
  /// starts a new one (F-PFERD-04). Returns the new assignment.
  @discardableResult
  public func move(to stable: Stable, on date: Date, in context: ModelContext) -> StableAssignment {
    for assignment in stableAssignments ?? [] where assignment.validFrom <= date {
      if assignment.validUntil.map({ $0 > date }) ?? true {
        assignment.validUntil = date
        assignment.touch()
      }
    }
    let assignment = StableAssignment(horse: self, stable: stable, validFrom: date)
    context.insert(assignment)
    touch()
    return assignment
  }

  /// Most recent measurement of `type`.
  public func latestMeasurement(of type: MeasurementType) -> BodyMeasurement? {
    (measurements ?? []).filter { $0.typeRaw == type.rawValue }.max { $0.timestamp < $1.timestamp }
  }
}

extension BodyMeasurement {
  /// Whether the value was computed with the estimation formula (F-MESS-09).
  public var isEstimated: Bool { methodRaw == MeasurementMethod.estimationFormula.rawValue }
}

extension MeasurementType {
  /// Method preselected in the entry form.
  public var defaultMethod: MeasurementMethod {
    switch self {
    case .weight: .scale
    case .heightAtWithers, .bellyGirth, .chestGirth, .bodyLength: .measuringTape
    case .bodyTemperature: .thermometer
    case .pulse, .respiratoryRate, .bodyConditionScore: .other
    }
  }

  /// Methods offered for this type.
  public var availableMethods: [MeasurementMethod] {
    switch self {
    case .weight: [.scale, .measuringTape, .estimationFormula, .other]
    case .heightAtWithers, .bellyGirth, .chestGirth, .bodyLength: [.measuringTape, .other]
    case .bodyTemperature: [.thermometer, .other]
    case .pulse, .respiratoryRate, .bodyConditionScore: [.other]
    }
  }
}

extension Horse {
  /// User-defined reference range of `type` (F-MESS-04). With several entries (possible after
  /// sync, since there is no unique constraint) the most recently updated one wins.
  public func referenceRange(for type: MeasurementType) -> ReferenceRange? {
    referenceRangeSettings(for: type).first.map { ReferenceRange(lower: $0.lower, upper: $0.upper) }
  }

  /// Stores or removes (`nil`) the reference range of `type`; removes duplicates.
  public func setReferenceRange(_ range: ReferenceRange?, for type: MeasurementType, in context: ModelContext) {
    var settings = referenceRangeSettings(for: type)
    if let range {
      let setting: ReferenceRangeSetting
      if settings.isEmpty {
        setting = ReferenceRangeSetting(horse: self, type: type, range: range)
        context.insert(setting)
      } else {
        setting = settings.removeFirst()
        setting.lower = range.lower
        setting.upper = range.upper
        setting.touch()
      }
    }
    settings.forEach(context.delete)
    touch()
  }

  /// Entries for `type`, most recently updated first.
  private func referenceRangeSettings(for type: MeasurementType) -> [ReferenceRangeSetting] {
    (referenceRanges ?? [])
      .filter { $0.measurementTypeRaw == type.rawValue && !$0.isDeleted }
      .sorted { $0.updatedAt > $1.updatedAt }
  }
}

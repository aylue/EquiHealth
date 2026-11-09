import Foundation
import SwiftData

extension EquiSchemaV2 {
  /// User-defined reference range of one measurement type for one horse (F-MESS-04, Q-015).
  /// A user setting, never a medical limit supplied by the app. Not unique by constraint
  /// (CloudKit); `Horse.referenceRange(for:)` uses the most recently updated entry.
  @Model
  public final class ReferenceRangeSetting: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var measurementTypeRaw: String = MeasurementType.weight.rawValue
    /// Lower bound in the SI unit of the measurement type.
    public var lower: Double = 0
    /// Upper bound in the SI unit of the measurement type.
    public var upper: Double = 0

    public var horse: Horse?

    public var measurementType: MeasurementType {
      get { MeasurementType(rawValue: measurementTypeRaw) ?? .weight }
      set { measurementTypeRaw = newValue.rawValue }
    }

    public init(horse: Horse?, type: MeasurementType, range: ReferenceRange) {
      self.horse = horse
      self.measurementTypeRaw = type.rawValue
      self.lower = range.lower
      self.upper = range.upper
    }
  }
}

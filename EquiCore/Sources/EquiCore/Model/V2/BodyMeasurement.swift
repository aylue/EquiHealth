import Foundation
import SwiftData

extension EquiSchemaV2 {
  /// A single measured value (SPEC entity `Measurement`, F-MESS-01).
  // ANNAHME: Swift-Klasse heißt `BodyMeasurement`, damit sie `Foundation.Measurement` nicht
  // verdeckt, das für die Anzeige gebraucht wird (F-ARCH-04). Siehe OPEN_QUESTIONS.md.
  @Model
  public final class BodyMeasurement: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    public var typeRaw: String = MeasurementType.weight.rawValue
    /// Value in the SI unit of `type` (`MeasurementType.storageUnitSymbol`).
    public var value: Double = 0
    public var timestamp: Date = Date()
    public var methodRaw: String?
    public var note: String = ""

    public var horse: Horse?

    public var type: MeasurementType {
      get { MeasurementType(rawValue: typeRaw) ?? .weight }
      set { typeRaw = newValue.rawValue }
    }

    public var method: MeasurementMethod? {
      get { methodRaw.flatMap(MeasurementMethod.init(rawValue:)) }
      set { methodRaw = newValue?.rawValue }
    }

    public init(
      horse: Horse?, type: MeasurementType, value: Double, timestamp: Date = .now,
      method: MeasurementMethod? = nil
    ) {
      self.horse = horse
      self.typeRaw = type.rawValue
      self.value = value
      self.timestamp = timestamp
      self.methodRaw = method?.rawValue
    }
  }
}

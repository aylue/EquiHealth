import Foundation
import SwiftData

extension EquiSchemaV3 {
  /// A training session written by the training app; read-only in EquiHealth (F-TRAIN-02, F-TRAIN-03).
  @Model
  public final class TrainingSession: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    /// Version of the training interface that wrote this record (`TrainingInterface.version`).
    public var interfaceVersion: Int = 1
    public var typeRaw: String = TrainingType.riding.rawValue
    public var start: Date = Date()
    public var end: Date?
    /// Seconds.
    public var duration: Double = 0
    /// Meters.
    public var distance: Double?
    /// Seconds per gait.
    public var walkDuration: Double?
    public var trotDuration: Double?
    public var canterDuration: Double?
    /// Beats per minute.
    public var heartRateAverage: Double?
    public var heartRateMax: Double?
    /// JSON-encoded `[TrainingRoutePoint]`.
    @Attribute(.externalStorage) public var routeData: Data?
    /// Bundle identifier of the writing app.
    public var sourceApp: String?
    public var note: String = ""

    public var horse: Horse?

    public var type: TrainingType {
      get { TrainingType(rawValue: typeRaw) ?? .other }
      set { typeRaw = newValue.rawValue }
    }

    public init(horse: Horse?, type: TrainingType, start: Date, duration: Double) {
      self.horse = horse
      self.typeRaw = type.rawValue
      self.start = start
      self.duration = duration
    }
  }
}

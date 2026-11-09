import Foundation

/// Contract with the planned training app (F-TRAIN-03). Documented in `INTERFACE.md` (phase 8).
public enum TrainingInterface {
  /// Bump on every change of `TrainingSession` or the shared `Horse` fields.
  public static let version = 1
  /// URL scheme of this app, e.g. `equihealth://horse/<uuid>` (F-TRAIN-05).
  public static let healthURLScheme = "equihealth"
  /// URL scheme of the training app, e.g. `equitraining://start?horse=<uuid>` (F-TRAIN-05).
  public static let trainingURLScheme = "equitraining"
}

/// One point of a recorded route, stored JSON-encoded in `TrainingSession.routeData`.
public struct TrainingRoutePoint: Codable, Equatable, Sendable {
  public var latitude: Double
  public var longitude: Double
  public var altitude: Double?
  public var timestamp: Date

  public init(latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date) {
    self.latitude = latitude
    self.longitude = longitude
    self.altitude = altitude
    self.timestamp = timestamp
  }
}

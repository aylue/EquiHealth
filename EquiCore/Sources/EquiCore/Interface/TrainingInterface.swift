import Foundation

/// Contract with the planned training app (F-TRAIN-01 to F-TRAIN-05). Documented in `INTERFACE.md`.
public enum TrainingInterface {
  /// Bump on every change of `TrainingSession`, the shared `Horse` fields or the deep links, and
  /// add a row to the version table in `INTERFACE.md`.
  public static let version = 1
  /// URL scheme of this app, e.g. `equihealth://horse/<uuid>` (F-TRAIN-05).
  public static let healthURLScheme = "equihealth"
  /// URL scheme of the training app, e.g. `equitraining://start?horse=<uuid>` (F-TRAIN-05).
  public static let trainingURLScheme = "equitraining"
  /// Planned bundle identifier of the training app; written to `TrainingSession.sourceApp`.
  public static let trainingAppBundleIdentifier = "de.aylu.EquiTraining"
  /// `sourceApp` of sample sessions from the debug menu (F-TRAIN-06).
  public static let sampleSourceApp = "de.aylu.EquiHealth.samples"

  /// `Horse` fields the training app may read (F-TRAIN-02, F-TRAIN-03). It writes none of them.
  public static let sharedHorseFields = ["id", "name", "callName", "photoData", "isArchived", "sortIndex"]
  /// `TrainingSession` fields, all written by the training app.
  public static let trainingSessionFields = [
    "id", "createdAt", "updatedAt", "createdBy", "lastModifiedBy", "interfaceVersion", "typeRaw", "start", "end",
    "duration", "distance", "walkDuration", "trotDuration", "canterDuration", "heartRateAverage", "heartRateMax",
    "routeData", "sourceApp", "note", "horse",
  ]
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

  /// Encoding used for `routeData`: JSON array, dates as seconds since 1970 (`Double`).
  public static func encode(_ points: [TrainingRoutePoint]) -> Data? {
    guard !points.isEmpty else { return nil }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    return try? encoder.encode(points)
  }

  /// Unreadable data gives an empty route instead of an error (data written by another app).
  public static func decode(_ data: Data?) -> [TrainingRoutePoint] {
    guard let data else { return [] }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return (try? decoder.decode([TrainingRoutePoint].self, from: data)) ?? []
  }
}

extension TrainingSession {
  public var route: [TrainingRoutePoint] {
    get { TrainingRoutePoint.decode(routeData) }
    set { routeData = TrainingRoutePoint.encode(newValue) }
  }

  /// Sum of the gait durations, if any is known.
  public var gaitTotal: Double? {
    let parts = [walkDuration, trotDuration, canterDuration].compactMap { $0 }
    return parts.isEmpty ? nil : parts.reduce(0, +)
  }
}

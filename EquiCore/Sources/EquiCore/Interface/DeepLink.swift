import Foundation

/// Deep links between EquiHealth and the training app (F-TRAIN-05).
public enum DeepLink: Equatable, Sendable {
  /// `equihealth://horse/<uuid>`: opens a horse in EquiHealth.
  case horse(UUID)

  /// Parses a URL opened in EquiHealth; `nil` for anything unknown.
  public init?(url: URL) {
    guard url.scheme?.lowercased() == TrainingInterface.healthURLScheme,
      url.host()?.lowercased() == "horse"
    else { return nil }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard parts.count == 1, let id = UUID(uuidString: parts[0]) else { return nil }
    self = .horse(id)
  }

  public var url: URL {
    switch self {
    case .horse(let id):
      URL(string: "\(TrainingInterface.healthURLScheme)://horse/\(id.uuidString)")!
    }
  }

  /// `equitraining://start?horse=<uuid>`: starts a session in the training app.
  public static func trainingStart(horseID: UUID) -> URL {
    var components = URLComponents()
    components.scheme = TrainingInterface.trainingURLScheme
    components.host = "start"
    components.queryItems = [URLQueryItem(name: "horse", value: horseID.uuidString)]
    return components.url!
  }

  /// URL used to check whether the training app is installed (`canOpenURL`).
  public static var trainingAppProbe: URL {
    URL(string: "\(TrainingInterface.trainingURLScheme)://")!
  }
}

import Foundation
import SwiftData

/// Creates realistic-looking sample sessions until the training app exists (F-TRAIN-06). Used by the
/// debug menu and tests; deterministic for a given seed.
public enum TrainingSampleGenerator {
  /// Fallback start point of routes when the horse has no stable location (Warendorf).
  public static let defaultOrigin = (latitude: 51.954, longitude: 7.993)

  /// Inserts sessions for the last `weeks` weeks (3 to 5 per week) and returns them.
  @discardableResult
  public static func insertSamples(
    for horse: Horse, weeks: Int = 4, now: Date = .now, seed: UInt64 = 42, in context: ModelContext,
    calendar: Calendar = .current
  ) -> [TrainingSession] {
    var random = SeededRandom(seed: seed)
    let origin =
      horse.stableAssignment(at: now)?.stable.flatMap { stable in
        stable.latitude.flatMap { lat in stable.longitude.map { (latitude: lat, longitude: $0) } }
      } ?? defaultOrigin
    let types: [TrainingType] = [.dressage, .jumping, .hacking, .lunging, .groundwork, .riding]
    var sessions: [TrainingSession] = []
    for weekOffset in 0..<weeks {
      let count = 3 + Int(random.next() % 3)
      for index in 0..<count {
        let daysBack = weekOffset * 7 + index * 2 + Int(random.next() % 2)
        guard let day = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: now)),
          let start = calendar.date(bySettingHour: 8 + Int(random.next() % 10), minute: 0, second: 0, of: day),
          start < now
        else { continue }
        let type = types[Int(random.next() % UInt64(types.count))]
        let minutes = Double(25 + random.next() % 50)
        let session = TrainingSession(horse: horse, type: type, start: start, duration: minutes * 60)
        session.end = start.addingTimeInterval(minutes * 60)
        session.interfaceVersion = TrainingInterface.version
        session.sourceApp = TrainingInterface.sampleSourceApp
        let walk = 0.4 + Double(random.next() % 20) / 100
        let canter = type == .lunging || type == .groundwork ? 0.05 : 0.1 + Double(random.next() % 15) / 100
        session.walkDuration = (minutes * 60 * walk).rounded()
        session.canterDuration = (minutes * 60 * canter).rounded()
        session.trotDuration = minutes * 60 - session.walkDuration! - session.canterDuration!
        session.heartRateAverage = Double(70 + random.next() % 40)
        session.heartRateMax = (session.heartRateAverage ?? 90) + Double(40 + random.next() % 60)
        if type == .hacking || type == .riding {
          let points = route(from: origin, start: start, minutes: Int(minutes), random: &random)
          session.route = points
          session.distance = distance(of: points)
        }
        session.note = String(localized: "Beispiel-Einheit")
        context.insert(session)
        sessions.append(session)
      }
    }
    return sessions
  }

  /// Removes the sample sessions of `horse` (only those with `sampleSourceApp`).
  public static func removeSamples(for horse: Horse, in context: ModelContext) {
    for session in horse.trainingSessions ?? [] where session.sourceApp == TrainingInterface.sampleSourceApp {
      context.delete(session)
    }
  }

  /// A closed loop of one point per minute around `origin`.
  static func route(
    from origin: (latitude: Double, longitude: Double), start: Date, minutes: Int, random: inout SeededRandom
  ) -> [TrainingRoutePoint] {
    let radius = 0.004 + Double(random.next() % 40) / 10_000
    let phase = Double(random.next() % 360) * .pi / 180
    let steps = max(minutes, 10)
    return (0...steps).map { step in
      let angle = phase + 2 * .pi * Double(step) / Double(steps)
      let wobble = 1 + 0.15 * sin(angle * 3)
      return TrainingRoutePoint(
        latitude: origin.latitude + radius * wobble * (sin(angle) - sin(phase)),
        longitude: origin.longitude + radius * 1.6 * wobble * (cos(angle) - cos(phase)),
        altitude: 60 + 5 * sin(angle * 2), timestamp: start.addingTimeInterval(Double(step) * 60))
    }
  }

  /// Length of a route in meters (haversine).
  public static func distance(of points: [TrainingRoutePoint]) -> Double {
    zip(points, points.dropFirst()).map { a, b in
      let earthRadius = 6_371_000.0
      let dLat = (b.latitude - a.latitude) * .pi / 180
      let dLon = (b.longitude - a.longitude) * .pi / 180
      let h =
        sin(dLat / 2) * sin(dLat / 2) + cos(a.latitude * .pi / 180) * cos(b.latitude * .pi / 180) * sin(dLon / 2)
        * sin(dLon / 2)
      return 2 * earthRadius * asin(min(1, sqrt(h)))
    }.reduce(0, +)
  }
}

/// Small deterministic generator (SplitMix64) so samples and tests are reproducible.
struct SeededRandom {
  private var state: UInt64

  init(seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

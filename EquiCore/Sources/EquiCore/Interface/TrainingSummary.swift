import Foundation

/// Training of one week (F-TRAIN-04): count, total duration, distribution by type and gait.
public struct TrainingWeekSummary: Equatable, Sendable, Identifiable {
  /// Start of the week (first weekday of `calendar`).
  public var weekStart: Date
  public var sessionCount: Int
  /// Seconds.
  public var totalDuration: Double
  /// Meters, only sessions with a distance.
  public var totalDistance: Double
  /// Seconds per training type.
  public var durationByType: [TrainingType: Double]
  public var walkDuration: Double
  public var trotDuration: Double
  public var canterDuration: Double

  public var id: Date { weekStart }

  /// Gait durations as shares of their sum; empty if no gait was recorded.
  public var gaitShares: [(gait: Gait, share: Double)] {
    let total = walkDuration + trotDuration + canterDuration
    guard total > 0 else { return [] }
    return [(.walk, walkDuration / total), (.trot, trotDuration / total), (.canter, canterDuration / total)]
  }
}

public enum Gait: String, CaseIterable, Sendable {
  case walk, trot, canter
}

extension Horse {
  /// Training sessions, newest first.
  public var sortedTrainingSessions: [TrainingSession] {
    (trainingSessions ?? []).sorted { $0.start > $1.start }
  }

  /// The last `weeks` weeks up to and including the week of `now`, oldest first; weeks without
  /// training are included with zero values (F-TRAIN-04).
  public func trainingWeeks(_ weeks: Int, now: Date = .now, calendar: Calendar = .current) -> [TrainingWeekSummary] {
    guard weeks > 0, let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
    let starts = (0..<weeks).reversed().compactMap {
      calendar.date(byAdding: .weekOfYear, value: -$0, to: currentWeek)
    }
    let grouped = Dictionary(grouping: trainingSessions ?? []) {
      calendar.dateInterval(of: .weekOfYear, for: $0.start)?.start ?? $0.start
    }
    return starts.map { start in
      let sessions = grouped[start] ?? []
      var byType: [TrainingType: Double] = [:]
      for session in sessions { byType[session.type, default: 0] += session.duration }
      return TrainingWeekSummary(
        weekStart: start, sessionCount: sessions.count, totalDuration: sessions.map(\.duration).reduce(0, +),
        totalDistance: sessions.compactMap(\.distance).reduce(0, +), durationByType: byType,
        walkDuration: sessions.compactMap(\.walkDuration).reduce(0, +),
        trotDuration: sessions.compactMap(\.trotDuration).reduce(0, +),
        canterDuration: sessions.compactMap(\.canterDuration).reduce(0, +))
    }
  }
}

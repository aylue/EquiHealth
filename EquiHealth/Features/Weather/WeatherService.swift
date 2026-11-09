import EquiCore
import Foundation
import Observation
import SwiftData

/// Weather for a horse on given days, using the stable it stood at on each day (F-WETTER-02).
@Observable
final class WeatherService {
  /// State of one day.
  enum DayState: Equatable {
    case weather(DailyWeather)
    /// No stable assigned on that day: show "Stall hinterlegen".
    case noStable
    /// The stable has no location yet.
    case noLocation(stableName: String)
    /// No data (offline, error or nothing returned).
    case unavailable
  }

  struct Lookup: Equatable {
    var states: [Date: DayState] = [:]
    /// A fetch failed; shown as a subtle hint, never as a dialog (F-WETTER-06).
    var hadError = false
  }

  /// Attribution required in every weather display (F-WETTER-05).
  static let attribution = String(localized: "Wetterdaten: Deutscher Wetterdienst, über Bright Sky")

  @ObservationIgnored private let repository: WeatherRepository
  @ObservationIgnored let provider: any WeatherProvider

  init(container: ModelContainer, provider: any WeatherProvider) {
    repository = WeatherRepository(modelContainer: container)
    self.provider = provider
  }

  func lookup(horse: Horse, days: [Date], now: Date = .now) async -> Lookup {
    let calendar = Calendar.current
    var lookup = Lookup()
    var groups: [String: (latitude: Double, longitude: Double, days: [Date])] = [:]
    for day in Set(days.map { calendar.startOfDay(for: $0) }) {
      let noon = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
      guard let stable = horse.stableAssignment(at: noon)?.stable else {
        lookup.states[day] = .noStable
        continue
      }
      guard let latitude = stable.latitude, let longitude = stable.longitude else {
        lookup.states[day] = .noLocation(stableName: stable.name)
        continue
      }
      let key = "\(CoordinateRounding.rounded(latitude)),\(CoordinateRounding.rounded(longitude))"
      groups[key, default: (latitude, longitude, [])].days.append(day)
    }
    for group in groups.values {
      let result = await repository.weather(
        for: group.days, latitude: group.latitude, longitude: group.longitude, provider: provider, now: now,
        calendar: calendar)
      lookup.hadError = lookup.hadError || result.error != nil
      let byDay = Dictionary(result.days.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
      for day in group.days {
        lookup.states[day] = byDay[day].map(DayState.weather) ?? .unavailable
      }
    }
    return lookup
  }
}

#if DEBUG
  /// Deterministic offline provider for UI tests (`-uiTesting`); `-weatherOffline` makes it fail.
  struct StubWeatherProvider: WeatherProvider {
    let id = "stub"
    let fails: Bool

    func hourlyWeather(
      latitude: Double, longitude: Double, from start: Date, to end: Date, timeZone: TimeZone
    ) async throws -> WeatherResponse {
      if fails { throw WeatherError.network }
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = timeZone
      var hours: [HourlyWeather] = []
      var time = start
      while time < end {
        let hour = calendar.component(.hour, from: time)
        let day = calendar.component(.day, from: time)
        hours.append(
          HourlyWeather(
            timestamp: time, temperature: Double(day % 5) + Double(hour) / 4, precipitation: hour < 4 ? 0.3 : 0,
            relativeHumidity: 85, windGustSpeed: 20 + Double(hour), icon: hour < 4 ? "rain" : "cloudy", sourceID: 1))
        time = time.addingTimeInterval(3600)
      }
      return WeatherResponse(hours: hours, stationNames: [1: "Teststation"])
    }
  }
#endif

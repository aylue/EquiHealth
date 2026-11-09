import Foundation

/// One hourly weather record (F-WETTER-01).
public struct HourlyWeather: Equatable, Sendable {
  public var timestamp: Date
  /// °C
  public var temperature: Double?
  /// mm
  public var precipitation: Double?
  /// %
  public var relativeHumidity: Double?
  /// km/h
  public var windGustSpeed: Double?
  /// Bright Sky icon, e.g. `rain`, `cloudy`, `partly-cloudy-day`.
  public var icon: String?
  public var sourceID: Int?

  public init(
    timestamp: Date, temperature: Double? = nil, precipitation: Double? = nil, relativeHumidity: Double? = nil,
    windGustSpeed: Double? = nil, icon: String? = nil, sourceID: Int? = nil
  ) {
    self.timestamp = timestamp
    self.temperature = temperature
    self.precipitation = precipitation
    self.relativeHumidity = relativeHumidity
    self.windGustSpeed = windGustSpeed
    self.icon = icon
    self.sourceID = sourceID
  }
}

/// Hourly records plus station names by source id.
public struct WeatherResponse: Equatable, Sendable {
  public var hours: [HourlyWeather]
  public var stationNames: [Int: String]

  public init(hours: [HourlyWeather], stationNames: [Int: String] = [:]) {
    self.hours = hours
    self.stationNames = stationNames
  }
}

/// Source of weather data, exchangeable and mockable (F-ARCH-03, F-WETTER-07).
public protocol WeatherProvider: Sendable {
  /// Stored in `WeatherDay.providerID`.
  var id: String { get }

  /// Hourly weather for `[start, end)` at the given (already rounded) coordinates.
  func hourlyWeather(
    latitude: Double, longitude: Double, from start: Date, to end: Date, timeZone: TimeZone
  ) async throws -> WeatherResponse
}

/// Coordinates are sent with two decimal places only (≈ 1 km, NF-01).
public enum CoordinateRounding {
  public static func rounded(_ value: Double) -> Double {
    (value * 100).rounded() / 100
  }
}

/// Errors of weather lookups. Never shown as a dialog (F-WETTER-06).
public enum WeatherError: Error, Equatable, Sendable {
  case network
  case invalidResponse
}

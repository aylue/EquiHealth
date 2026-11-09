import Foundation

/// Weather of one day at one place, aggregated from hourly values (F-WETTER-01).
public struct DailyWeather: Equatable, Sendable {
  /// Start of the day in the requested time zone.
  public var day: Date
  public var latitude: Double
  public var longitude: Double
  public var temperatureMin: Double?
  public var temperatureMean: Double?
  public var temperatureMax: Double?
  public var precipitationSum: Double?
  public var relativeHumidityMean: Double?
  public var windGustMax: Double?
  /// Prevailing Bright Sky icon without day/night suffix, e.g. `rain`, `cloudy`, `partly-cloudy`.
  public var condition: String?
  public var stationName: String?

  public init(
    day: Date, latitude: Double, longitude: Double, temperatureMin: Double? = nil, temperatureMean: Double? = nil,
    temperatureMax: Double? = nil, precipitationSum: Double? = nil, relativeHumidityMean: Double? = nil,
    windGustMax: Double? = nil, condition: String? = nil, stationName: String? = nil
  ) {
    self.day = day
    self.latitude = latitude
    self.longitude = longitude
    self.temperatureMin = temperatureMin
    self.temperatureMean = temperatureMean
    self.temperatureMax = temperatureMax
    self.precipitationSum = precipitationSum
    self.relativeHumidityMean = relativeHumidityMean
    self.windGustMax = windGustMax
    self.condition = condition
    self.stationName = stationName
  }

  init(_ cached: WeatherDay) {
    self.init(
      day: cached.date, latitude: cached.latitude, longitude: cached.longitude,
      temperatureMin: cached.temperatureMin, temperatureMean: cached.temperatureMean,
      temperatureMax: cached.temperatureMax, precipitationSum: cached.precipitationSum,
      relativeHumidityMean: cached.relativeHumidityMean, windGustMax: cached.windGustMax,
      condition: cached.condition, stationName: cached.stationName)
  }
}

/// Aggregates hourly values to daily values (F-WETTER-01).
public enum WeatherAggregator {
  /// Severity order used to break ties of the prevailing condition.
  static let conditionPriority = [
    "thunderstorm", "hail", "snow", "sleet", "rain", "fog", "wind", "cloudy", "partly-cloudy", "clear",
  ]

  public static func daily(
    from response: WeatherResponse, latitude: Double, longitude: Double, calendar: Calendar
  ) -> [DailyWeather] {
    let byDay = Dictionary(grouping: response.hours) { calendar.startOfDay(for: $0.timestamp) }
    return byDay.keys.sorted().map { day in
      let hours = byDay[day] ?? []
      let temperatures = hours.compactMap(\.temperature)
      let precipitation = hours.compactMap(\.precipitation)
      let humidity = hours.compactMap(\.relativeHumidity)
      let gusts = hours.compactMap(\.windGustSpeed)
      let station = Dictionary(grouping: hours.compactMap(\.sourceID)) { $0 }
        .max { $0.value.count < $1.value.count }?.key
        .flatMap { response.stationNames[$0] }
      return DailyWeather(
        day: day, latitude: latitude, longitude: longitude,
        temperatureMin: temperatures.min(),
        temperatureMean: temperatures.isEmpty ? nil : temperatures.reduce(0, +) / Double(temperatures.count),
        temperatureMax: temperatures.max(),
        precipitationSum: precipitation.isEmpty ? nil : precipitation.reduce(0, +),
        relativeHumidityMean: humidity.isEmpty ? nil : humidity.reduce(0, +) / Double(humidity.count),
        windGustMax: gusts.max(),
        condition: prevailingCondition(hours.compactMap(\.icon)),
        stationName: station)
    }
  }

  /// Most frequent icon (day/night suffix removed); ties go to the more severe condition.
  static func prevailingCondition(_ icons: [String]) -> String? {
    let normalized = icons.map {
      $0.replacingOccurrences(of: "-day", with: "").replacingOccurrences(of: "-night", with: "")
    }
    let counts = Dictionary(grouping: normalized) { $0 }.mapValues(\.count)
    func rank(_ condition: String) -> Int { conditionPriority.firstIndex(of: condition) ?? conditionPriority.count }
    return counts.max { lhs, rhs in
      lhs.value != rhs.value ? lhs.value < rhs.value : rank(lhs.key) > rank(rhs.key)
    }?.key
  }
}

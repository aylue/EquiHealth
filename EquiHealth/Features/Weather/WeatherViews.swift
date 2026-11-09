import EquiCore
import SwiftUI

extension DailyWeather {
  var systemImage: String {
    switch condition {
    case "clear": "sun.max"
    case "partly-cloudy": "cloud.sun"
    case "cloudy": "cloud"
    case "fog": "cloud.fog"
    case "wind": "wind"
    case "rain": "cloud.rain"
    case "sleet": "cloud.sleet"
    case "snow": "cloud.snow"
    case "hail": "cloud.hail"
    case "thunderstorm": "cloud.bolt.rain"
    default: "cloud"
    }
  }

  var conditionTitle: String {
    switch condition {
    case "clear": String(localized: "klar")
    case "partly-cloudy": String(localized: "teils bewölkt")
    case "cloudy": String(localized: "bewölkt")
    case "fog": String(localized: "Nebel")
    case "wind": String(localized: "windig")
    case "rain": String(localized: "Regen")
    case "sleet": String(localized: "Schneeregen")
    case "snow": String(localized: "Schnee")
    case "hail": String(localized: "Hagel")
    case "thunderstorm": String(localized: "Gewitter")
    default: String(localized: "unbekannt")
    }
  }

  private static func temperature(_ value: Double) -> String {
    Measurement(value: value, unit: UnitTemperature.celsius)
      .formatted(
        .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
  }

  /// "4 – 10 °C"
  var temperatureRange: String? {
    guard let temperatureMin, let temperatureMax else { return nil }
    return "\(Self.temperature(temperatureMin)) – \(Self.temperature(temperatureMax))"
  }

  /// "1,2 mm"
  var precipitationText: String? {
    precipitationSum.map {
      Measurement(value: $0, unit: UnitLength.millimeters)
        .formatted(
          .measurement(
            width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }
  }

  /// "1,2 mm · 80 % · Böen 45 km/h"
  var detailLine: String {
    var parts: [String] = []
    if let precipitationText { parts.append(precipitationText) }
    if let relativeHumidityMean {
      parts.append((relativeHumidityMean / 100).formatted(.percent.precision(.fractionLength(0))))
    }
    if let windGustMax {
      let gust = Measurement(value: windGustMax, unit: UnitSpeed.kilometersPerHour)
        .formatted(
          .measurement(
            width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
      parts.append(String(localized: "Böen \(gust)"))
    }
    return parts.joined(separator: " · ")
  }
}

/// Weather of several days, e.g. a symptom's start day and the three days before (F-GESUND-05).
struct WeatherDaysSection: View {
  @Environment(WeatherService.self) private var weather
  let horse: Horse
  let days: [Date]
  let title: LocalizedStringKey

  @State private var lookup: WeatherService.Lookup?

  var body: some View {
    Section {
      if let lookup {
        content(lookup)
      } else {
        HStack {
          ProgressView()
          Text("Wetter wird geladen …").foregroundStyle(.secondary)
        }
      }
    } header: {
      Text(title)
    } footer: {
      VStack(alignment: .leading, spacing: 4) {
        if lookup?.hadError == true {
          Text("Wetterdaten sind gerade nicht erreichbar. Angezeigt wird, was bereits gespeichert ist.")
        }
        Text(WeatherService.attribution)
          .accessibilityIdentifier("weather.attribution")
      }
    }
    .task(id: days) {
      lookup = await weather.lookup(horse: horse, days: days)
    }
  }

  @ViewBuilder private func content(_ lookup: WeatherService.Lookup) -> some View {
    let sorted = days.map { Calendar.current.startOfDay(for: $0) }.sorted(by: >)
    let states = sorted.map { lookup.states[$0] ?? .unavailable }
    if states.allSatisfy({ $0 == .noStable }) {
      Label("Stall hinterlegen, um Wetterdaten zu sehen.", systemImage: "house")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("weather.noStable")
    } else if case .noLocation(let name) = states.first(where: { if case .noLocation = $0 { true } else { false } }),
      states.allSatisfy({ if case .weather = $0 { false } else { true } })
    {
      Label("Für „\(name)“ ist noch kein Standort hinterlegt.", systemImage: "location.slash")
        .foregroundStyle(.secondary)
    } else {
      ForEach(Array(zip(sorted, states)), id: \.0) { day, state in
        WeatherDayRow(day: day, state: state)
      }
    }
  }
}

/// One day of weather.
struct WeatherDayRow: View {
  let day: Date
  let state: WeatherService.DayState

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
          .font(.subheadline)
        switch state {
        case .weather(let weather):
          Text(weather.detailLine).font(.caption).foregroundStyle(.secondary)
        case .noStable:
          Text("kein Stall hinterlegt").font(.caption).foregroundStyle(.secondary)
        case .noLocation:
          Text("Stall ohne Standort").font(.caption).foregroundStyle(.secondary)
        case .unavailable:
          Text("keine Daten").font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      if case .weather(let weather) = state {
        Image(systemName: weather.systemImage)
          .symbolRenderingMode(.multicolor)
          .accessibilityLabel(Text(weather.conditionTitle))
        Text(weather.temperatureRange ?? "–").monospacedDigit()
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("weather.day")
  }
}

/// Compact weather line for one day, e.g. in the timeline (F-WETTER-04).
struct WeatherInlineLabel: View {
  let state: WeatherService.DayState?

  var body: some View {
    if case .weather(let weather) = state {
      HStack(spacing: 6) {
        Image(systemName: weather.systemImage).accessibilityLabel(Text(weather.conditionTitle))
        Text([weather.temperatureRange, weather.precipitationText].compactMap { $0 }.joined(separator: " · "))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("weather.inline")
    }
  }
}

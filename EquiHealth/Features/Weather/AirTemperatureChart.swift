import Charts
import EquiCore
import SwiftUI

/// Daily air temperature for the visible chart range, shown below the body temperature (F-MESS-05).
// ANNAHME: Eigene Diagrammfläche mit gleicher Zeitachse statt zweiter y-Achse, weil Körper- (≈ 38 °C)
// und Lufttemperatur (≈ −10 bis 35 °C) auf einer Achse die Körperwerte flachdrücken würden. Q-043.
struct AirTemperatureChart: View {
  @Environment(WeatherService.self) private var weather
  let horse: Horse
  let domain: DateInterval

  /// Bright Sky requests are limited to roughly one year of days here.
  private static let maximumDays = 400

  @State private var lookup: WeatherService.Lookup?

  private var days: [Date] {
    let calendar = Calendar.current
    var result: [Date] = []
    var day = calendar.startOfDay(for: domain.start)
    let end = min(domain.end, .now)
    while day < end && result.count < Self.maximumDays {
      result.append(day)
      day = calendar.date(byAdding: .day, value: 1, to: day) ?? end
    }
    return result
  }

  var body: some View {
    let values: [DailyWeather] = (lookup?.states.values ?? [:].values).compactMap {
      if case .weather(let weather) = $0 { return weather } else { return nil }
    }
    .sorted { $0.day < $1.day }

    Group {
      if lookup == nil {
        ProgressView().frame(maxWidth: .infinity, minHeight: 120)
      } else if values.isEmpty {
        Text(emptyText).font(.footnote).foregroundStyle(.secondary)
      } else {
        Chart(values, id: \.day) { day in
          if let min = day.temperatureMin, let max = day.temperatureMax {
            AreaMark(
              x: .value("Tag", day.day, unit: .day),
              yStart: .value("Minimum", min),
              yEnd: .value("Maximum", max)
            )
            .foregroundStyle(.secondary.opacity(0.2))
            .accessibilityHidden(true)
          }
          if let mean = day.temperatureMean {
            LineMark(x: .value("Tag", day.day, unit: .day), y: .value("Lufttemperatur", mean))
              .foregroundStyle(.secondary)
              .interpolationMethod(.monotone)
              .accessibilityLabel(Text(day.day.formatted(date: .abbreviated, time: .omitted)))
              .accessibilityValue(Text(day.temperatureRange ?? ""))
          }
        }
        .chartXScale(domain: domain.start...domain.end)
        .chartYAxisLabel("°C Luft")
        .frame(height: 140)
        .accessibilityIdentifier("airTemperatureChart")
      }
    }
    .task(id: domain) {
      lookup = await weather.lookup(horse: horse, days: days)
    }
  }

  private var emptyText: String {
    let states = Array((lookup?.states ?? [:]).values)
    if !states.isEmpty, states.allSatisfy({ $0 == .noStable }) {
      return String(localized: "Stall hinterlegen, um die Lufttemperatur zu sehen.")
    }
    if lookup?.hadError == true {
      return String(localized: "Wetterdaten sind gerade nicht erreichbar.")
    }
    return String(localized: "Keine Wetterdaten für diesen Zeitraum.")
  }
}

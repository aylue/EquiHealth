import Foundation
import SwiftData
import Testing

@testable import EquiCore

/// Mock provider: deterministic hourly values, counts requests, can fail (F-ARCH-03).
final class MockWeatherProvider: WeatherProvider, @unchecked Sendable {
  let id = "mock"
  private let lock = NSLock()
  private var _requests: [(latitude: Double, longitude: Double, start: Date, end: Date)] = []
  var fails = false

  var requests: [(latitude: Double, longitude: Double, start: Date, end: Date)] {
    lock.withLock { _requests }
  }

  func hourlyWeather(
    latitude: Double, longitude: Double, from start: Date, to end: Date, timeZone: TimeZone
  ) async throws -> WeatherResponse {
    lock.withLock { _requests.append((latitude, longitude, start, end)) }
    if lock.withLock({ fails }) { throw WeatherError.network }
    var hours: [HourlyWeather] = []
    var time = start
    var hour = 0
    while time < end {
      hours.append(
        HourlyWeather(
          timestamp: time, temperature: Double(hour % 24) / 2, precipitation: hour % 24 < 3 ? 0.5 : 0,
          relativeHumidity: 80, windGustSpeed: Double(10 + hour % 24), icon: hour % 24 < 3 ? "rain" : "cloudy",
          sourceID: 1))
      time = time.addingTimeInterval(3600)
      hour += 1
    }
    return WeatherResponse(hours: hours, stationNames: [1: "Münster/Osnabrück"])
  }
}

@Suite("Wetter (F-WETTER)")
struct WeatherTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
  }

  private func makeRepository() throws -> WeatherRepository {
    WeatherRepository(modelContainer: try EquiModelContainer.make(inMemory: true))
  }

  @Test("NF-01: Koordinaten werden auf 2 Nachkommastellen gerundet")
  func rounding() {
    #expect(CoordinateRounding.rounded(51.96236) == 51.96)
    #expect(CoordinateRounding.rounded(7.62571) == 7.63)
    #expect(CoordinateRounding.rounded(-0.005) == -0.01 || CoordinateRounding.rounded(-0.005) == 0)
  }

  @Test("F-WETTER-01: Anfrage an Bright Sky mit gerundeten Koordinaten und Zeitraum")
  func brightSkyRequest() throws {
    let request = BrightSkyProvider().request(
      latitude: 51.962_36, longitude: 7.625_71, from: date(2025, 11, 12), to: date(2025, 11, 16),
      timeZone: calendar.timeZone)
    let url = try #require(request.url)
    #expect(url.host() == "api.brightsky.dev")
    #expect(url.path() == "/weather")
    let items = Dictionary(
      uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map {
        ($0.name, $0.value ?? "")
      })
    #expect(items["lat"] == "51.96")
    #expect(items["lon"] == "7.63")
    #expect(items["date"]?.hasPrefix("2025-11-12T00:00:00") == true)
    #expect(items["last_date"]?.hasPrefix("2025-11-16T00:00:00") == true)
    #expect(items["tz"] == "Europe/Berlin")
  }

  @Test("F-WETTER-01: Zeitzonen-Offset wird in der Anfrage kodiert")
  func brightSkyRequestEncodesOffset() throws {
    let request = BrightSkyProvider().request(
      latitude: 51.96, longitude: 7.63, from: date(2025, 11, 12), to: date(2025, 11, 16),
      timeZone: calendar.timeZone)
    let query = try #require(request.url?.query(percentEncoded: true))
    #expect(!query.contains("+"))
    #expect(query.contains("date=2025-11-12T00:00:00%2B01:00"))
    #expect(query.contains("last_date=2025-11-16T00:00:00%2B01:00"))
    let items = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.first { $0.name == "date" }?.value == "2025-11-12T00:00:00+01:00")
  }

  @Test("F-WETTER-01: Bright-Sky-JSON wird gelesen und zu Tageswerten verdichtet")
  func decodeAndAggregate() throws {
    let json = """
      {"weather":[
       {"timestamp":"2025-11-12T00:00:00+01:00","temperature":4.0,"precipitation":0.2,"relative_humidity":90,"wind_gust_speed":20.0,"icon":"rain","source_id":7},
       {"timestamp":"2025-11-12T12:00:00+01:00","temperature":10.0,"precipitation":1.0,"relative_humidity":70,"wind_gust_speed":45.5,"icon":"rain","source_id":7},
       {"timestamp":"2025-11-12T18:00:00+01:00","temperature":7.0,"precipitation":0.0,"relative_humidity":80,"wind_gust_speed":null,"icon":"cloudy","source_id":7},
       {"timestamp":"2025-11-13T00:00:00+01:00","temperature":3.0,"precipitation":0.0,"relative_humidity":95,"wind_gust_speed":12.0,"icon":"clear-night","source_id":7}
      ],"sources":[{"id":7,"station_name":"Münster/Osnabrück"}]}
      """
    let response = try BrightSkyProvider.decode(Data(json.utf8))
    let days = WeatherAggregator.daily(from: response, latitude: 51.96, longitude: 7.63, calendar: calendar)
    #expect(days.count == 2)
    let first = try #require(days.first)
    #expect(first.day == date(2025, 11, 12))
    #expect(first.temperatureMin == 4)
    #expect(first.temperatureMax == 10)
    #expect(first.temperatureMean == 7)
    #expect(abs((first.precipitationSum ?? 0) - 1.2) < 0.0001)
    #expect(first.relativeHumidityMean == 80)
    #expect(first.windGustMax == 45.5)
    #expect(first.condition == "rain")
    #expect(first.stationName == "Münster/Osnabrück")
    #expect(days[1].condition == "clear", "Tag-/Nacht-Zusatz wird entfernt")
  }

  @Test("Ungültige Antworten führen zu einem Fehler statt eines Absturzes")
  func invalidJSON() {
    #expect(throws: WeatherError.invalidResponse) { try BrightSkyProvider.decode(Data("<html>".utf8)) }
  }

  @Test("Abnahme Phase 5: Symptom vom letzten Jahr zeigt Tageswerte; zweiter Aufruf lädt aus dem Cache")
  func cacheForPastDays() async throws {
    let repository = try makeRepository()
    let provider = MockWeatherProvider()
    let symptomStart = date(2025, 11, 15, 9)
    let days = (0...3).map { calendar.date(byAdding: .day, value: -$0, to: symptomStart)! }
    let now = date(2026, 11, 9, 12)

    let first = await repository.weather(
      for: days, latitude: 51.962_36, longitude: 7.625_71, provider: provider, now: now, calendar: calendar)
    #expect(first.days.map(\.day) == [date(2025, 11, 12), date(2025, 11, 13), date(2025, 11, 14), date(2025, 11, 15)])
    #expect(first.days.allSatisfy { $0.temperatureMax == 11.5 && $0.stationName == "Münster/Osnabrück" })
    #expect(first.fetchCount == 1)
    #expect(provider.requests.count == 1)
    #expect(provider.requests.first?.latitude == 51.96)
    #expect(provider.requests.first?.longitude == 7.63)
    #expect(provider.requests.first?.start == date(2025, 11, 12))
    #expect(provider.requests.first?.end == date(2025, 11, 16))

    let second = await repository.weather(
      for: days, latitude: 51.96, longitude: 7.63, provider: provider, now: now.addingTimeInterval(86_400),
      calendar: calendar)
    #expect(second.fetchCount == 0, "Vergangene Tage werden nicht erneut abgerufen")
    #expect(second.days == first.days)
    #expect(provider.requests.count == 1)
  }

  @Test("F-WETTER-03: Der aktuelle Tag wird höchstens stündlich neu abgerufen")
  func todayRefreshesHourly() async throws {
    let repository = try makeRepository()
    let provider = MockWeatherProvider()
    let now = date(2026, 11, 9, 10)
    _ = await repository.weather(
      for: [now], latitude: 51.96, longitude: 7.63, provider: provider, now: now, calendar: calendar)
    let soon = await repository.weather(
      for: [now], latitude: 51.96, longitude: 7.63, provider: provider, now: now.addingTimeInterval(30 * 60),
      calendar: calendar)
    #expect(soon.fetchCount == 0)
    let later = await repository.weather(
      for: [now], latitude: 51.96, longitude: 7.63, provider: provider, now: now.addingTimeInterval(61 * 60),
      calendar: calendar)
    #expect(later.fetchCount == 1)
    #expect(provider.requests.count == 2)
  }

  @Test("F-WETTER-03: Ein am selben Tag abgerufener Tag wird nach Tagesende einmal vervollständigt")
  func partialPastDayIsCompletedOnce() async throws {
    let repository = try makeRepository()
    let provider = MockWeatherProvider()
    let day = date(2026, 11, 8)
    _ = await repository.weather(
      for: [day], latitude: 51.96, longitude: 7.63, provider: provider, now: date(2026, 11, 8, 15), calendar: calendar)
    _ = await repository.weather(
      for: [day], latitude: 51.96, longitude: 7.63, provider: provider, now: date(2026, 11, 9, 8), calendar: calendar)
    let third = await repository.weather(
      for: [day], latitude: 51.96, longitude: 7.63, provider: provider, now: date(2026, 11, 10, 8), calendar: calendar)
    #expect(provider.requests.count == 2)
    #expect(third.fetchCount == 0)
  }

  @Test("F-WETTER-06: Ohne Netz liefert die Abfrage zwischengespeicherte Daten und einen Fehler, ohne zu werfen")
  func offlineUsesCache() async throws {
    let repository = try makeRepository()
    let provider = MockWeatherProvider()
    let now = date(2026, 11, 9, 12)
    let cachedDay = date(2025, 11, 14)
    _ = await repository.weather(
      for: [cachedDay], latitude: 51.96, longitude: 7.63, provider: provider, now: now, calendar: calendar)

    provider.fails = true
    let offline = await repository.weather(
      for: [date(2025, 11, 13), cachedDay], latitude: 51.96, longitude: 7.63, provider: provider, now: now,
      calendar: calendar)
    #expect(offline.error == .network)
    #expect(offline.days.map(\.day) == [cachedDay], "Zwischengespeicherter Tag bleibt sichtbar")

    let nothingCached = await repository.weather(
      for: [date(2024, 1, 1)], latitude: 48.14, longitude: 11.58, provider: provider, now: now, calendar: calendar)
    #expect(nothingCached.days.isEmpty)
    #expect(nothingCached.error == .network)
  }

  @Test("Verstreute Tage werden in zusammenhängende Blöcke von höchstens 31 Tagen aufgeteilt")
  func scatteredDaysAreChunked() async throws {
    let repository = try makeRepository()
    let provider = MockWeatherProvider()
    let spring = (0..<3).map { calendar.date(byAdding: .day, value: $0, to: date(2025, 3, 1))! }
    let summer = (0..<40).map { calendar.date(byAdding: .day, value: $0, to: date(2025, 7, 1))! }
    let result = await repository.weather(
      for: spring + summer, latitude: 51.96, longitude: 7.63, provider: provider, now: date(2026, 11, 9),
      calendar: calendar)
    #expect(result.fetchCount == 3, "März (3 Tage), Juli (31 Tage), August (9 Tage)")
    #expect(result.days.count == 43)
    #expect(provider.requests.map { calendar.dateComponents([.day], from: $0.start, to: $0.end).day } == [3, 31, 9])
  }

  @Test("Verstreute Tage innerhalb von 31 Tagen kommen mit einer Anfrage; Lückentage werden mitgespeichert")
  func scatteredDaysWithinWindowNeedOneRequest() async throws {
    let repository = try makeRepository()
    let provider = MockWeatherProvider()
    let days = [1, 5, 12, 20, 30].map { date(2025, 6, $0) }
    let first = await repository.weather(
      for: days, latitude: 51.96, longitude: 7.63, provider: provider, now: date(2026, 11, 9), calendar: calendar)
    #expect(first.fetchCount == 1)
    #expect(first.days.count == 5, "Nur die gewünschten Tage im Ergebnis")
    let gap = await repository.weather(
      for: [date(2025, 6, 15)], latitude: 51.96, longitude: 7.63, provider: provider, now: date(2026, 11, 9),
      calendar: calendar)
    #expect(gap.fetchCount == 0, "Lückentag kommt aus dem Cache")
  }

  @Test("Wetter-Cache liegt im lokalen Store, nicht im synchronisierten")
  func weatherDayIsLocalOnly() {
    #expect(CurrentSchema.localOnlyModels.map { "\($0)" } == ["\(WeatherDay.self)"])
    #expect(!CurrentSchema.syncedModels.contains { $0 == WeatherDay.self })
  }
}

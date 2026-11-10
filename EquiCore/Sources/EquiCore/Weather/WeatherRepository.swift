import Foundation
import SwiftData

/// Result of a weather lookup: everything available, plus whether a fetch failed (F-WETTER-06).
public struct WeatherLookupResult: Sendable {
  public var days: [DailyWeather]
  /// Set when fetching failed; cached data in `days` is still usable.
  public var error: WeatherError?
  /// Number of network requests made for this lookup (0 = served from cache). After a failure the
  /// remaining requests are skipped.
  public var fetchCount: Int
}

/// Caches daily weather in the local-only `WeatherDay` store (F-WETTER-03). Runs off the main actor.
///
/// A past day is fetched again only if its cached data was fetched before the day was over; the
/// current and future days are refreshed at most hourly.
@ModelActor
public actor WeatherRepository {
  public func weather(
    for days: [Date], latitude: Double, longitude: Double, provider: any WeatherProvider, now: Date = .now,
    calendar: Calendar = .current
  ) async -> WeatherLookupResult {
    let lat = CoordinateRounding.rounded(latitude)
    let lon = CoordinateRounding.rounded(longitude)
    let wanted = Array(Set(days.map { calendar.startOfDay(for: $0) })).sorted()
    guard let first = wanted.first, let last = wanted.last else {
      return WeatherLookupResult(days: [], error: nil, fetchCount: 0)
    }

    var cached = cachedDays(from: first, through: last, latitude: lat, longitude: lon)
    let stale = wanted.filter { day in
      guard let entry = cached[day] else { return true }
      return !isFresh(entry, now: now, calendar: calendar)
    }

    var failure: WeatherError?
    var fetchCount = 0
    let chunks = Self.chunks(of: stale, calendar: calendar)
    for chunk in chunks {
      guard let fetchStart = chunk.first, let fetchLast = chunk.last,
        let fetchEnd = calendar.date(byAdding: .day, value: 1, to: fetchLast)
      else { continue }
      fetchCount += 1
      do {
        let response = try await provider.hourlyWeather(
          latitude: lat, longitude: lon, from: fetchStart, to: fetchEnd, timeZone: calendar.timeZone)
        let fetched = WeatherAggregator.daily(from: response, latitude: lat, longitude: lon, calendar: calendar)
        for daily in fetched where daily.day >= fetchStart && daily.day < fetchEnd {
          cached[daily.day] = store(daily, providerID: provider.id, fetchedAt: now, existing: cached[daily.day])
        }
      } catch {
        failure = (error as? WeatherError) ?? .network
        break  // offline: do not try the remaining chunks
      }
    }
    if !chunks.isEmpty { try? modelContext.save() }
    let result = wanted.compactMap { cached[$0] }.map(DailyWeather.init)
    return WeatherLookupResult(days: result, error: failure, fetchCount: fetchCount)
  }

  /// Groups days into windows spanning at most `maxDays` calendar days; one request per window.
  /// Days in gaps are fetched too (cheap) and cached, so scattered entries need few requests.
  static func chunks(of days: [Date], maxDays: Int = 31, calendar: Calendar) -> [[Date]] {
    var result: [[Date]] = []
    for day in days.sorted() {
      if var current = result.last, let first = current.first,
        let limit = calendar.date(byAdding: .day, value: maxDays, to: first), day < limit
      {
        current.append(day)
        result[result.count - 1] = current
      } else {
        result.append([day])
      }
    }
    return result
  }

  private func isFresh(_ entry: WeatherDay, now: Date, calendar: Calendar) -> Bool {
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date
    if endOfDay <= now {
      // Past day: final once it was fetched after the day had ended.
      return entry.fetchedAt >= endOfDay
    }
    return now.timeIntervalSince(entry.fetchedAt) < 60 * 60
  }

  private func cachedDays(from first: Date, through last: Date, latitude: Double, longitude: Double)
    -> [Date: WeatherDay]
  {
    let descriptor = FetchDescriptor<WeatherDay>(
      predicate: #Predicate {
        $0.date >= first && $0.date <= last && $0.latitude == latitude && $0.longitude == longitude
      })
    let entries = (try? modelContext.fetch(descriptor)) ?? []
    var result: [Date: WeatherDay] = [:]
    for entry in entries where result[entry.date].map({ entry.fetchedAt > $0.fetchedAt }) ?? true {
      result[entry.date] = entry
    }
    return result
  }

  private func store(_ daily: DailyWeather, providerID: String, fetchedAt: Date, existing: WeatherDay?) -> WeatherDay {
    let entry = existing ?? WeatherDay(date: daily.day, latitude: daily.latitude, longitude: daily.longitude)
    if existing == nil { modelContext.insert(entry) }
    entry.temperatureMin = daily.temperatureMin
    entry.temperatureMean = daily.temperatureMean
    entry.temperatureMax = daily.temperatureMax
    entry.precipitationSum = daily.precipitationSum
    entry.relativeHumidityMean = daily.relativeHumidityMean
    entry.windGustMax = daily.windGustMax
    entry.condition = daily.condition
    entry.stationName = daily.stationName
    entry.providerID = providerID
    entry.fetchedAt = fetchedAt
    entry.updatedAt = fetchedAt
    return entry
  }
}

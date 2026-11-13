import Foundation

/// Bright Sky, a JSON API for the open data of Deutscher Wetterdienst, without API key (F-WETTER-01).
/// The only network access of the app (NF-01).
public struct BrightSkyProvider: WeatherProvider {
  public let id = "brightsky"
  private let session: URLSession
  private let baseURL: URL

  public init(session: URLSession = .shared, baseURL: URL = URL(string: "https://api.brightsky.dev")!) {
    self.session = session
    self.baseURL = baseURL
  }

  /// `GET /weather?lat=..&lon=..&date=..&last_date=..&tz=..`
  public func request(
    latitude: Double, longitude: Double, from start: Date, to end: Date, timeZone: TimeZone
  ) -> URLRequest {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone, .withColonSeparatorInTimeZone,
    ]
    formatter.timeZone = timeZone
    var components = URLComponents(url: baseURL.appending(path: "weather"), resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "lat", value: String(format: "%.2f", CoordinateRounding.rounded(latitude))),
      URLQueryItem(name: "lon", value: String(format: "%.2f", CoordinateRounding.rounded(longitude))),
      URLQueryItem(name: "date", value: formatter.string(from: start)),
      URLQueryItem(name: "last_date", value: formatter.string(from: end)),
      URLQueryItem(name: "tz", value: timeZone.identifier),
    ]
    // URLComponents leaves "+" unencoded in queries; the server reads it as a space and rejects
    // offsets like "+01:00" with HTTP 422.
    components.percentEncodedQuery = components.percentEncodedQuery?
      .replacingOccurrences(of: "+", with: "%2B")
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return request
  }

  public func hourlyWeather(
    latitude: Double, longitude: Double, from start: Date, to end: Date, timeZone: TimeZone
  ) async throws -> WeatherResponse {
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(
        for: request(latitude: latitude, longitude: longitude, from: start, to: end, timeZone: timeZone))
    } catch {
      throw WeatherError.network
    }
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw WeatherError.invalidResponse
    }
    return try Self.decode(data)
  }

  /// Decodes a Bright Sky `/weather` response.
  public static func decode(_ data: Data) throws -> WeatherResponse {
    struct Payload: Decodable {
      struct Record: Decodable {
        let timestamp: Date
        let temperature: Double?
        let precipitation: Double?
        let relativeHumidity: Double?
        let windGustSpeed: Double?
        let icon: String?
        let sourceId: Int?
      }
      struct Source: Decodable {
        let id: Int
        let stationName: String?
      }
      let weather: [Record]
      let sources: [Source]?
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let payload = try? decoder.decode(Payload.self, from: data) else { throw WeatherError.invalidResponse }
    let hours = payload.weather.map {
      HourlyWeather(
        timestamp: $0.timestamp, temperature: $0.temperature, precipitation: $0.precipitation,
        relativeHumidity: $0.relativeHumidity, windGustSpeed: $0.windGustSpeed, icon: $0.icon,
        sourceID: $0.sourceId)
    }
    var names: [Int: String] = [:]
    for source in payload.sources ?? [] {
      if let name = source.stationName { names[source.id] = name }
    }
    return WeatherResponse(hours: hours, stationNames: names)
  }
}

import Foundation
import SwiftData

extension EquiSchemaV1 {
  /// Locally cached daily weather (F-WETTER-03). Lives in its own local store and is never synced.
  @Model
  public final class WeatherDay: EquiRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var createdBy: String?
    public var lastModifiedBy: String?

    /// Start of the day in the stable's local time zone.
    public var date: Date = Date()
    /// Coordinates rounded to 2 decimal places (NF-01).
    public var latitude: Double = 0
    public var longitude: Double = 0
    /// °C
    public var temperatureMin: Double?
    public var temperatureMean: Double?
    public var temperatureMax: Double?
    /// mm
    public var precipitationSum: Double?
    /// %
    public var relativeHumidityMean: Double?
    /// km/h
    public var windGustMax: Double?
    public var condition: String?
    public var stationName: String?
    public var providerID: String = "brightsky"
    public var fetchedAt: Date = Date()

    public init(date: Date, latitude: Double, longitude: Double) {
      self.date = date
      self.latitude = latitude
      self.longitude = longitude
    }
  }
}

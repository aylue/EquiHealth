import EquiCore
import Foundation
import SwiftData
import Testing

@testable import EquiHealth

@Suite("Wetter pro Pferd und Tag (F-WETTER-02, F-WETTER-06)")
@MainActor
struct WeatherServiceTests {
  private struct FailingProvider: WeatherProvider {
    let id = "failing"
    func hourlyWeather(
      latitude: Double, longitude: Double, from start: Date, to end: Date, timeZone: TimeZone
    ) async throws -> WeatherResponse {
      throw WeatherError.network
    }
  }

  private func day(_ offset: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
  }

  @Test("Stall des jeweiligen Tages; ohne Stall „Stall hinterlegen“, ohne Standort eigener Hinweis")
  func stablePerDay() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = container.mainContext
    let horse = Horse(name: "Luna")
    let north = Stable(name: "Nord", latitude: 53.55, longitude: 9.99)
    let south = Stable(name: "Süd", latitude: 48.14, longitude: 11.58)
    let noLocation = Stable(name: "Ohne Ort")
    for model in [horse, north, south, noLocation] as [any PersistentModel] { context.insert(model) }
    horse.move(to: north, on: day(-10), in: context)
    horse.move(to: south, on: day(-5), in: context)
    horse.move(to: noLocation, on: day(-2), in: context)
    try context.save()

    let service = WeatherService(container: container, provider: StubWeatherProvider(fails: false))
    let lookup = await service.lookup(horse: horse, days: [day(-12), day(-8), day(-4), day(-1)])

    #expect(lookup.states[day(-12)] == .noStable)
    #expect(lookup.states[day(-1)] == .noLocation(stableName: "Ohne Ort"))
    guard case .weather(let northWeather) = lookup.states[day(-8)],
      case .weather(let southWeather) = lookup.states[day(-4)]
    else {
      Issue.record("Wetter für beide Ställe erwartet")
      return
    }
    #expect(northWeather.latitude == 53.55)
    #expect(southWeather.latitude == 48.14)
    #expect(!lookup.hadError)
  }

  @Test("F-WETTER-06: Ohne Netz kein Fehler nach außen, nur ein Hinweis")
  func offline() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = container.mainContext
    let horse = Horse(name: "Luna")
    let stable = Stable(name: "Hof", latitude: 51.96, longitude: 7.63)
    context.insert(horse)
    context.insert(stable)
    horse.move(to: stable, on: StableAssignment.unknownStart, in: context)
    try context.save()

    let service = WeatherService(container: container, provider: FailingProvider())
    let lookup = await service.lookup(horse: horse, days: [day(-400), day(-399)])
    #expect(lookup.hadError)
    #expect(lookup.states.values.allSatisfy { $0 == .unavailable })
  }
}

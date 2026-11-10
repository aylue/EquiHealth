import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Trainings-Schnittstelle (F-TRAIN)")
struct TrainingInterfaceTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    calendar.firstWeekday = 2  // Monday
    calendar.minimumDaysInFirstWeek = 4
    return calendar
  }

  private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
  }

  @Test("F-TRAIN-05: equihealth://horse/<uuid> wird erkannt, Unbekanntes nicht")
  func healthDeepLink() throws {
    let id = UUID()
    #expect(DeepLink(url: URL(string: "equihealth://horse/\(id.uuidString)")!) == .horse(id))
    #expect(DeepLink(url: URL(string: "EquiHealth://Horse/\(id.uuidString.lowercased())")!) == .horse(id))
    #expect(DeepLink(url: DeepLink.horse(id).url) == .horse(id))
    #expect(DeepLink(url: URL(string: "equihealth://horse/keine-uuid")!) == nil)
    #expect(DeepLink(url: URL(string: "equihealth://stable/\(id.uuidString)")!) == nil)
    #expect(DeepLink(url: URL(string: "https://horse/\(id.uuidString)")!) == nil)
    #expect(DeepLink(url: URL(string: "equihealth://horse/\(id.uuidString)/extra")!) == nil)
  }

  @Test("F-TRAIN-05: equitraining://start?horse=<uuid>")
  func trainingStartLink() {
    let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    #expect(
      DeepLink.trainingStart(horseID: id).absoluteString
        == "equitraining://start?horse=11111111-2222-3333-4444-555555555555")
    #expect(DeepLink.trainingAppProbe.scheme == "equitraining")
  }

  @Test("F-TRAIN-03: Die dokumentierte Feldliste entspricht dem Modell; Version gesetzt")
  func fieldListMatchesModel() throws {
    let schema = Schema(versionedSchema: CurrentSchema.self)
    let session = try #require(schema.entities.first { $0.name == "TrainingSession" })
    let modelFields = Set(session.attributes.map(\.name) + session.relationships.map(\.name))
    #expect(modelFields == Set(TrainingInterface.trainingSessionFields))
    let horse = try #require(schema.entities.first { $0.name == "Horse" })
    let horseFields = Set(horse.attributes.map(\.name))
    #expect(Set(TrainingInterface.sharedHorseFields).isSubset(of: horseFields))
    #expect(TrainingInterface.version >= 1)
  }

  @Test("Route wird als JSON gespeichert; unlesbare Daten ergeben eine leere Route")
  func routeCoding() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let session = TrainingSession(horse: nil, type: .hacking, start: date(2026, 11, 9), duration: 600)
    context.insert(session)
    let points = [
      TrainingRoutePoint(latitude: 51.95, longitude: 7.99, altitude: 60, timestamp: date(2026, 11, 9)),
      TrainingRoutePoint(latitude: 51.96, longitude: 7.99, timestamp: date(2026, 11, 9, 11)),
    ]
    session.route = points
    #expect(session.route == points)
    let json = try #require(session.routeData.flatMap { String(data: $0, encoding: .utf8) })
    #expect(json.contains("\"latitude\":51.95"))
    #expect(abs(TrainingSampleGenerator.distance(of: points) - 1112) < 5, "≈ 1,1 km je 0,01° Breite")
    session.routeData = Data("kaputt".utf8)
    #expect(session.route.isEmpty)
    session.route = []
    #expect(session.routeData == nil)
  }

  @Test("F-TRAIN-04: Wochenübersicht mit Anzahl, Dauer, Typen, Gangarten und leeren Wochen")
  func weekSummary() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let horse = Horse(name: "Luna")
    context.insert(horse)
    func add(_ day: Date, _ type: TrainingType, minutes: Double, walk: Double?, trot: Double?, canter: Double?) {
      let session = TrainingSession(horse: horse, type: type, start: day, duration: minutes * 60)
      session.walkDuration = walk.map { $0 * 60 }
      session.trotDuration = trot.map { $0 * 60 }
      session.canterDuration = canter.map { $0 * 60 }
      session.distance = 1000
      context.insert(session)
    }
    // Week of Mon 9.11.2026: two sessions; week of 2.11.: none; week of 26.10.: one.
    add(date(2026, 11, 9), .dressage, minutes: 45, walk: 15, trot: 20, canter: 10)
    add(date(2026, 11, 11), .hacking, minutes: 60, walk: 40, trot: 15, canter: 5)
    add(date(2026, 10, 28), .dressage, minutes: 30, walk: nil, trot: nil, canter: nil)
    // Sunday 8.11. belongs to the previous week.
    add(date(2026, 11, 8, 18), .lunging, minutes: 20, walk: 10, trot: 10, canter: 0)
    try context.save()

    let weeks = horse.trainingWeeks(3, now: date(2026, 11, 12), calendar: calendar)
    #expect(weeks.map(\.weekStart) == [date(2026, 10, 26, 0), date(2026, 11, 2, 0), date(2026, 11, 9, 0)])
    #expect(weeks.map(\.sessionCount) == [1, 1, 2])
    let current = try #require(weeks.last)
    #expect(current.totalDuration == 6300)
    #expect(current.totalDistance == 2000)
    let expectedTypes: [TrainingType: Double] = [.dressage: 2700, .hacking: 3600]
    #expect(current.durationByType == expectedTypes)
    #expect(current.walkDuration == 3300)
    #expect(current.gaitShares.map(\.gait) == [.walk, .trot, .canter])
    let shareSum: Double = current.gaitShares.map(\.share).reduce(0, +)
    #expect(abs(shareSum - 1) < 1e-9)
    #expect(weeks[0].gaitShares.isEmpty, "Ohne Gangarten keine Verteilung")
  }

  @Test("F-TRAIN-06: Beispiel-Einheiten sind reproduzierbar, plausibel und wieder entfernbar")
  func samples() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let horse = Horse(name: "Luna")
    let stable = Stable(name: "Hof", latitude: 51.96, longitude: 7.63)
    context.insert(horse)
    context.insert(stable)
    horse.move(to: stable, on: StableAssignment.unknownStart, in: context)
    let manual = TrainingSession(horse: horse, type: .other, start: date(2026, 11, 1), duration: 600)
    context.insert(manual)
    let now = date(2026, 11, 12, 20)

    let first = TrainingSampleGenerator.insertSamples(
      for: horse, weeks: 4, now: now, seed: 7, in: context, calendar: calendar)
    try context.save()
    #expect((12...20).contains(first.count))
    #expect(first.allSatisfy { $0.start < now && $0.sourceApp == TrainingInterface.sampleSourceApp })
    for session in first {
      let gaits: Double = session.gaitTotal ?? 0
      #expect(abs(gaits - session.duration) < 1, "Gangarten ergeben die Dauer")
    }
    let withRoute = first.filter { !$0.route.isEmpty }
    #expect(!withRoute.isEmpty)
    #expect(withRoute.allSatisfy { ($0.distance ?? 0) > 500.0 })
    for session in withRoute {
      let startLatitude: Double = session.route[0].latitude
      #expect(abs(startLatitude - 51.96) < 0.001, "Route beginnt am Stall")
    }
    #expect(horse.trainingWeeks(4, now: now, calendar: calendar).allSatisfy { $0.sessionCount >= 1 })

    let other = ModelContext(try EquiModelContainer.make(inMemory: true))
    let twin = Horse(name: "Luna")
    other.insert(twin)
    let second = TrainingSampleGenerator.insertSamples(
      for: twin, weeks: 4, now: now, seed: 7, in: other, calendar: calendar)
    #expect(second.map(\.start) == first.map(\.start))
    #expect(second.map(\.typeRaw) == first.map(\.typeRaw))

    TrainingSampleGenerator.removeSamples(for: horse, in: context)
    try context.save()
    #expect(horse.trainingSessions?.map(\.id) == [manual.id], "Nur Beispiele werden gelöscht")
  }
}

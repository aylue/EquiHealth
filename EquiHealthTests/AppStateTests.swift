import EquiCore
import Foundation
import SwiftData
import Testing

@testable import EquiHealth

@Suite("AppState (F-PFERD-02, F-MESS-04)")
@MainActor
struct AppStateTests {
  private func freshDefaults() -> UserDefaults {
    let name = "AppStateTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  @Test("F-PFERD-02: Auswahl des aktiven Pferdes bleibt nach Neustart erhalten")
  func activeHorsePersists() {
    let defaults = freshDefaults()
    let id = UUID()
    AppState(defaults: defaults).activeHorseID = id
    #expect(AppState(defaults: defaults).activeHorseID == id)
  }

  @Test("Q-015: Alte Referenzbereiche aus UserDefaults werden einmalig ins Datenmodell übernommen")
  func legacyReferenceRangesAreMigrated() throws {
    let defaults = freshDefaults()
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let luna = Horse(name: "Luna")
    let max = Horse(name: "Max")
    context.insert(luna)
    context.insert(max)
    max.setReferenceRange(ReferenceRange(lower: 600, upper: 650), for: .weight, in: context)
    try context.save()

    let encoder = JSONEncoder()
    let lunaKey = "referenceRange.\(luna.id.uuidString).weight"
    let maxKey = "referenceRange.\(max.id.uuidString).weight"
    defaults.set(try encoder.encode(ReferenceRange(lower: 500, upper: 560)), forKey: lunaKey)
    defaults.set(try encoder.encode(ReferenceRange(lower: 1, upper: 2)), forKey: maxKey)

    AppState(defaults: defaults).migrateLegacyReferenceRanges(of: [luna, max], in: context)

    #expect(luna.referenceRange(for: .weight) == ReferenceRange(lower: 500, upper: 560))
    #expect(max.referenceRange(for: .weight) == ReferenceRange(lower: 600, upper: 650), "Datenmodell hat Vorrang")
    #expect(defaults.data(forKey: lunaKey) == nil)
    #expect(defaults.data(forKey: maxKey) == nil)
  }

  @Test("Übersicht: Gewicht und Temperatur sind standardmäßig angeheftet, Änderungen bleiben erhalten")
  func pinnedTypes() {
    let defaults = freshDefaults()
    let state = AppState(defaults: defaults)
    #expect(state.pinnedMeasurementTypes == [.weight, .bodyTemperature])
    state.pinnedMeasurementTypes = [.heightAtWithers]
    #expect(AppState(defaults: defaults).pinnedMeasurementTypes == [.heightAtWithers])
  }

  @Test("Onboarding-Status bleibt erhalten")
  func onboardingFlag() {
    let defaults = freshDefaults()
    #expect(!AppState(defaults: defaults).hasCompletedOnboarding)
    AppState(defaults: defaults).hasCompletedOnboarding = true
    #expect(AppState(defaults: defaults).hasCompletedOnboarding)
  }
}

@Suite("Anzeige von Messwerten (F-ARCH-04)")
@MainActor
struct MeasurementDisplayTests {
  @Test("Einheiten werden über Measurement formatiert")
  func formatting() {
    #expect(MeasurementType.weight.format(540).contains("540"))
    #expect(MeasurementType.weight.format(540).contains("kg"))
    #expect(MeasurementType.bodyTemperature.format(37.6).contains("°C"))
    #expect(MeasurementType.heightAtWithers.format(165).contains("cm"))
  }
}

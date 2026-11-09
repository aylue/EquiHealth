import EquiCore
import Foundation
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

  @Test("F-MESS-04: Referenzbereich pro Pferd und Messtyp speichern und entfernen")
  func referenceRangesPersistPerHorse() {
    let defaults = freshDefaults()
    let luna = UUID()
    let max = UUID()
    let state = AppState(defaults: defaults)
    state.setReferenceRange(ReferenceRange(lower: 500, upper: 560), for: .weight, horseID: luna)

    let reloaded = AppState(defaults: defaults)
    #expect(reloaded.referenceRange(for: .weight, horseID: luna) == ReferenceRange(lower: 500, upper: 560))
    #expect(reloaded.referenceRange(for: .weight, horseID: max) == nil)
    #expect(reloaded.referenceRange(for: .bodyTemperature, horseID: luna) == nil)

    reloaded.setReferenceRange(nil, for: .weight, horseID: luna)
    #expect(AppState(defaults: defaults).referenceRange(for: .weight, horseID: luna) == nil)
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

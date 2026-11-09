import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("ModelContainer und Datenmodell")
struct ModelContainerTests {
  @Test("F-ARCH-06: Hauptstore ist ohne Entwicklerkonto rein lokal")
  func mainStoreIsLocal() {
    #expect(isLocal(EquiModelContainer.mainStoreCloudKitDatabase))
  }

  @Test("Container mit beiden Stores lässt sich erzeugen; WeatherDay liegt im lokalen Wetter-Store")
  func containerBuildsWithSeparateWeatherStore() throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let names = container.configurations.map(\.name)
    #expect(names.contains(EquiModelContainer.mainStoreName))
    #expect(names.contains(EquiModelContainer.weatherStoreName))

    let weather = try #require(
      container.configurations.first { $0.name == EquiModelContainer.weatherStoreName })
    #expect(weather.schema?.entities.map(\.name) == ["WeatherDay"])
    #expect(isLocal(weather.cloudKitDatabase))
  }

  @Test("F-PFERD-01: Löschen eines Pferdes löscht alle zugehörigen Einträge")
  func deletingHorseCascades() throws {
    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)

    let horse = Horse(name: "Luna")
    context.insert(horse)
    let treatment = Treatment(horse: horse, kind: .veterinarian)
    context.insert(treatment)
    context.insert(Medication(treatment: treatment, productName: "Präparat"))
    context.insert(BodyMeasurement(horse: horse, type: .weight, value: 540, method: .scale))
    context.insert(SymptomEntry(horse: horse, category: .colic, severity: .severe))
    let contact = Contact(name: "Dr. Beispiel", role: .veterinarian)
    context.insert(contact)
    treatment.contact = contact
    try context.save()

    context.delete(horse)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Horse>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Treatment>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Medication>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<BodyMeasurement>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<SymptomEntry>()) == 0)
    // Shared master data survives (F-TEIL-01).
    #expect(try context.fetchCount(FetchDescriptor<Contact>()) == 1)
  }

  @Test("Enums werden als String-Rohwert gespeichert")
  func enumsRoundTripThroughRawValues() {
    let measurement = BodyMeasurement(horse: nil, type: .chestGirth, value: 190, method: .measuringTape)
    #expect(measurement.typeRaw == "chestGirth")
    #expect(measurement.methodRaw == "measuringTape")
    measurement.type = .bodyTemperature
    #expect(measurement.type == .bodyTemperature)

    let medication = Medication(treatment: nil, productName: "Impfstoff")
    medication.vaccinationTargets = [.influenza, .tetanus]
    #expect(medication.vaccinationTargetsRaw == ["influenza", "tetanus"])
  }

  @Test("Symptom-Details werden als Codable-Struct gespeichert")
  func symptomDetailsRoundTrip() {
    let symptom = SymptomEntry(horse: nil, category: .colic, severity: .severe)
    #expect(symptom.detailsData == nil)
    let details = SymptomDetails(
      colic: .init(duration: 3600, signs: [.pawing, .rolling], veterinarianCalled: true))
    symptom.details = details
    #expect(symptom.detailsData != nil)
    #expect(symptom.details == details)
  }

  /// `CloudKitDatabase` is not `Equatable`; compare its description instead.
  private func isLocal(_ database: ModelConfiguration.CloudKitDatabase) -> Bool {
    String(describing: database) == String(describing: ModelConfiguration.CloudKitDatabase.none)
  }
}

import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("iCloud-Sync und Teilen vorbereitet (F-SYNC, F-TEIL)")
struct SyncPreparationTests {
  @Test("SPEC 4.10: Bei ausgeschaltetem Flag immer „noch nicht verfügbar“")
  func disabledIsNotAvailable() {
    #expect(
      SyncStatus.evaluate(isEnabled: false, account: .available, lastSuccessfulSync: .now, lastEventFailed: false)
        == .notAvailable)
    #expect(
      SyncStatus.evaluate(
        isEnabled: FeatureFlags.cloudSyncEnabled, account: nil, lastSuccessfulSync: nil, lastEventFailed: false)
        == .notAvailable)
  }

  @Test("F-SYNC-03: Kontostatus und letzter Abgleich bei eingeschaltetem Sync")
  func enabledStates() {
    let date = Date(timeIntervalSince1970: 1_794_300_000)
    #expect(
      SyncStatus.evaluate(isEnabled: true, account: nil, lastSuccessfulSync: nil, lastEventFailed: false) == .checking)
    #expect(
      SyncStatus.evaluate(isEnabled: true, account: .noAccount, lastSuccessfulSync: date, lastEventFailed: false)
        == .accountUnavailable(.noAccount))
    #expect(
      SyncStatus.evaluate(isEnabled: true, account: .available, lastSuccessfulSync: date, lastEventFailed: false)
        == .active(lastSync: date))
    #expect(
      SyncStatus.evaluate(isEnabled: true, account: .available, lastSuccessfulSync: date, lastEventFailed: true)
        == .failed(lastSync: date))
  }

  @Test("F-ARCH-06: Hauptstore lokal, solange der Sync aus ist; Wetter-Cache immer lokal")
  func storesAreLocal() {
    let configurations = EquiModelContainer.configurations(
      synced: CurrentSchema.syncedModels, localOnly: CurrentSchema.localOnlyModels, inMemory: true,
      storeDirectory: nil)
    #expect(configurations.count == 2)
    #expect(configurations.allSatisfy { $0.cloudKitContainerIdentifier == nil }, "Kein CloudKit-Container")
  }

  @Test("Hauptstore synchronisiert nur mit Flag und nie im Speicher (Tests, UI-Tests)")
  func containerSelection() {
    #expect(EquiModelContainer.mainStoreContainerIdentifier(syncEnabled: false, inMemory: false) == nil)
    #expect(EquiModelContainer.mainStoreContainerIdentifier(syncEnabled: true, inMemory: true) == nil)
    #expect(
      EquiModelContainer.mainStoreContainerIdentifier(syncEnabled: true, inMemory: false)
        == "iCloud.de.aylu.EquiHealth")
  }

  @Test("Das CloudKit-Schema lässt sich bei ausgeschaltetem Sync nicht anlegen")
  func schemaInitializerRefusesWhileDisabled() {
    #expect(throws: CloudKitSchemaInitializer.InitializerError.syncDisabled) {
      try CloudKitSchemaInitializer.initializeDevelopmentSchema(storeDirectory: FileManager.default.temporaryDirectory)
    }
  }

  @Test("F-TEIL-01: Alle Einträge eines Pferdes sind über das Pferd erreichbar, Stammdaten nur referenziert")
  func horseIsRootOfAllRecords() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let luna = Horse(name: "Luna")
    let max = Horse(name: "Max")
    context.insert(luna)
    context.insert(max)
    let stable = Stable(name: "Hof")
    let hay = Feed(name: "Heu", category: .roughage)
    let vet = Contact(name: "Dr. Weber", role: .veterinarian)
    for model in [stable, hay, vet] as [any PersistentModel] { context.insert(model) }
    luna.move(to: stable, on: StableAssignment.unknownStart, in: context)
    max.move(to: stable, on: StableAssignment.unknownStart, in: context)
    context.insert(BodyMeasurement(horse: luna, type: .weight, value: 540))
    luna.setReferenceRange(ReferenceRange(lower: 500, upper: 560), for: .weight, in: context)
    luna.applyFeedingPlan(
      [FeedingPlanLine(feedID: hay.id, amount: 8, unit: .kilogram, meal: .adLibitum)], from: .now, feeds: [hay],
      in: context)
    context.insert(FeedingLog(horse: luna, feed: hay, amount: 1, unit: .kilogram))
    let condition = Condition(horse: luna, name: "Kolik")
    context.insert(condition)
    let treatment = Treatment(horse: luna, kind: .veterinarian)
    treatment.contact = vet
    context.insert(treatment)
    context.insert(Medication(treatment: treatment, productName: "Flunixin"))
    let report = EquiCore.Attachment(fileData: Data([1]), contentType: "com.adobe.pdf", title: "Befund")
    report.treatment = treatment
    context.insert(report)
    let symptom = SymptomEntry(horse: luna, category: .colic, severity: .severe)
    context.insert(symptom)
    let photo = EquiCore.Attachment(fileData: Data([2]), contentType: "public.jpeg", title: "Foto")
    photo.symptom = symptom
    context.insert(photo)
    context.insert(
      ReminderRule(horse: luna, kind: .farrier, title: "Hufschmied", intervalValue: 6, intervalUnit: .weeks))
    context.insert(TrainingSession(horse: luna, type: .dressage, start: .now, duration: 1800))
    context.insert(BodyMeasurement(horse: max, type: .weight, value: 610))
    try context.save()

    let graph = HorseRecordGraph(horse: luna)
    let ownedIDs = Set(graph.ownedRecords.map(\.id))
    let masterIDs = Set(graph.referencedMasterData.map(\.id))

    // Every non-master record of Luna is reachable; nothing of Max.
    func ids<T: EquiRecord>(_ type: T.Type) throws -> Set<UUID> {
      Set(try context.fetch(FetchDescriptor<T>()).map(\.id))
    }
    let maxIDs = Set(
      graph.ownedRecords.filter { record in
        (record as? BodyMeasurement)?.horse === max || (record as? StableAssignment)?.horse === max
      }.map(\.id))
    #expect(maxIDs.isEmpty)
    #expect(try ids(Medication.self).isSubset(of: ownedIDs))
    #expect(try ids(EquiCore.Attachment.self).isSubset(of: ownedIDs))
    #expect(try ids(SymptomEntry.self).isSubset(of: ownedIDs))
    #expect(try ids(Condition.self).isSubset(of: ownedIDs))
    #expect(try ids(ReminderRule.self).isSubset(of: ownedIDs))
    #expect(try ids(TrainingSession.self).isSubset(of: ownedIDs))
    // Stall-Zuordnung, Messwert, Referenzbereich, Planposition, Zusatzgabe, Krankheit, Behandlung,
    // Medikament, Befund, Symptom, Foto, Erinnerung, Trainingseinheit.
    #expect(graph.ownedRecords.count == 13, "gefunden: \(graph.ownedRecords.count)")
    #expect(masterIDs == [stable.id, hay.id, vet.id])
    #expect(ownedIDs.isDisjoint(with: masterIDs))
  }
}

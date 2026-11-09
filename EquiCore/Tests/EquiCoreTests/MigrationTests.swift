import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Schema-Versionen und Migration (F-ARCH-08, NF-10)")
struct MigrationTests {
  /// All schema versions in migration order.
  static let versions: [any VersionedSchema.Type] = [EquiSchemaV1.self, EquiSchemaV2.self, EquiSchemaV3.self]

  @Test(
    "F-ARCH-08: Jede Schemaversion ist eine rein additive Erweiterung der vorherigen", arguments: 1..<versions.count)
  func versionIsAdditive(index: Int) throws {
    let old = Schema(versionedSchema: Self.versions[index - 1])
    let new = Schema(versionedSchema: Self.versions[index])
    for oldEntity in old.entities {
      let newEntity = try #require(
        new.entities.first { $0.name == oldEntity.name }, "Entität \(oldEntity.name) fehlt in V\(index + 1)")
      for attribute in oldEntity.attributes {
        let match = newEntity.attributes.first { $0.name == attribute.name }
        #expect(match != nil, "\(oldEntity.name).\(attribute.name) fehlt")
        #expect(match?.valueType == attribute.valueType, "\(oldEntity.name).\(attribute.name) hat neuen Typ")
        #expect(match?.isOptional == attribute.isOptional, "\(oldEntity.name).\(attribute.name) Optionalität geändert")
      }
      for relationship in oldEntity.relationships {
        let match = newEntity.relationships.first { $0.name == relationship.name }
        #expect(match?.destination == relationship.destination, "\(oldEntity.name).\(relationship.name) geändert")
      }
    }
  }

  @Test("Migrationsplan kennt alle Versionen in Reihenfolge")
  func migrationPlanListsAllVersions() {
    #expect(EquiMigrationPlan.schemas.map { "\($0)" } == Self.versions.map { "\($0)" })
    #expect(EquiMigrationPlan.stages.count == Self.versions.count - 1)
  }

  @Test("F-ARCH-08: Auch eingefrorene Schemaversionen sind CloudKit-konform", arguments: 0..<versions.count)
  func frozenVersionsAreCloudKitCompliant(index: Int) {
    for entity in Schema(versionedSchema: Self.versions[index]).entities {
      for attribute in entity.attributes {
        #expect(attribute.isOptional || attribute.defaultValue != nil, "\(entity.name).\(attribute.name)")
        #expect(!attribute.isUnique)
      }
      for relationship in entity.relationships {
        #expect(relationship.isOptional && relationship.inverseName != nil, "\(entity.name).\(relationship.name)")
      }
    }
  }

  @Test("Ein Store mit Schema V1 wird beim Öffnen auf die aktuelle Version migriert, Daten bleiben erhalten")
  func migratesV1StoreOnDisk() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "EquiMigration-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let horseID: UUID
    do {
      let v1Container = try ModelContainer(
        for: Schema(versionedSchema: EquiSchemaV1.self),
        configurations: EquiModelContainer.configurations(
          synced: EquiSchemaV1.syncedModels, localOnly: EquiSchemaV1.localOnlyModels,
          inMemory: false, storeDirectory: directory))
      let context = ModelContext(v1Container)
      let horse = EquiSchemaV1.Horse(name: "Luna")
      context.insert(horse)
      context.insert(EquiSchemaV1.BodyMeasurement(horse: horse, type: .weight, value: 540, method: .scale))
      try context.save()
      horseID = horse.id
    }

    let container = try EquiModelContainer.make(storeDirectory: directory)
    let context = ModelContext(container)
    let horses = try context.fetch(FetchDescriptor<Horse>())
    let horse = try #require(horses.first)
    #expect(horses.count == 1)
    #expect(horse.id == horseID)
    #expect(horse.name == "Luna")
    #expect(horse.latestMeasurement(of: .weight)?.value == 540)
    #expect(horse.referenceRanges?.isEmpty ?? true)

    horse.setReferenceRange(ReferenceRange(lower: 500, upper: 560), for: .weight, in: context)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<ReferenceRangeSetting>()) == 1)
  }
}

@Suite("Referenzbereiche im Datenmodell (F-MESS-04, Q-015)")
struct ReferenceRangeSettingTests {
  @Test("Pro Pferd und Messtyp speichern, ändern, entfernen")
  func perHorseAndType() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let luna = Horse(name: "Luna")
    let max = Horse(name: "Max")
    context.insert(luna)
    context.insert(max)

    luna.setReferenceRange(ReferenceRange(lower: 500, upper: 560), for: .weight, in: context)
    try context.save()
    #expect(luna.referenceRange(for: .weight) == ReferenceRange(lower: 500, upper: 560))
    #expect(luna.referenceRange(for: .bodyTemperature) == nil)
    #expect(max.referenceRange(for: .weight) == nil)

    luna.setReferenceRange(ReferenceRange(lower: 510, upper: 550), for: .weight, in: context)
    try context.save()
    #expect(luna.referenceRange(for: .weight) == ReferenceRange(lower: 510, upper: 550))
    #expect(try context.fetchCount(FetchDescriptor<ReferenceRangeSetting>()) == 1)

    luna.setReferenceRange(nil, for: .weight, in: context)
    try context.save()
    #expect(luna.referenceRange(for: .weight) == nil)
    #expect(try context.fetchCount(FetchDescriptor<ReferenceRangeSetting>()) == 0)
  }

  @Test("Doppelte Einträge (z. B. nach Sync): der zuletzt geänderte gilt, Speichern räumt auf")
  func duplicatesResolveToNewest() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let horse = Horse(name: "Luna")
    context.insert(horse)
    let older = ReferenceRangeSetting(horse: horse, type: .weight, range: ReferenceRange(lower: 400, upper: 450))
    older.updatedAt = Date(timeIntervalSince1970: 1_000)
    let newer = ReferenceRangeSetting(horse: horse, type: .weight, range: ReferenceRange(lower: 500, upper: 560))
    newer.updatedAt = Date(timeIntervalSince1970: 2_000)
    context.insert(older)
    context.insert(newer)
    try context.save()

    #expect(horse.referenceRange(for: .weight) == ReferenceRange(lower: 500, upper: 560))
    horse.setReferenceRange(ReferenceRange(lower: 505, upper: 555), for: .weight, in: context)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<ReferenceRangeSetting>()) == 1)
    #expect(horse.referenceRange(for: .weight) == ReferenceRange(lower: 505, upper: 555))
  }

  @Test("F-PFERD-01: Löschen des Pferdes löscht seine Referenzbereiche")
  func cascadeOnHorseDelete() throws {
    let context = ModelContext(try EquiModelContainer.make(inMemory: true))
    let horse = Horse(name: "Luna")
    context.insert(horse)
    horse.setReferenceRange(ReferenceRange(lower: 37, upper: 38), for: .bodyTemperature, in: context)
    try context.save()
    context.delete(horse)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<ReferenceRangeSetting>()) == 0)
  }
}

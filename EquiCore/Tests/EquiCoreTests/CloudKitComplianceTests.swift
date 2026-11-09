import Foundation
import SwiftData
import Testing

@testable import EquiCore

/// Verifies the CloudKit rules for the data model (SPEC section 2, F-ARCH-08).
@Suite("CloudKit-Konformität des Schemas (F-ARCH-08)")
struct CloudKitComplianceTests {
  /// The current schema; older versions are covered by `MigrationTests`.
  private let schema = Schema(versionedSchema: CurrentSchema.self)

  /// Binary attributes that are intentionally small and therefore kept inline.
  private let inlineBinaryAttributes: Set<String> = ["SymptomEntry.detailsData"]

  @Test("Aktuelles Schema enthält alle Entitäten aus SPEC Abschnitt 3 plus ReferenceRangeSetting")
  func schemaContainsAllEntities() {
    let names = Set(schema.entities.map(\.name))
    #expect(
      names == [
        "Horse", "Stable", "StableAssignment", "BodyMeasurement", "Feed", "FeedingPlanItem",
        "FeedingLog", "SymptomEntry", "Condition", "Treatment", "Medication", "Contact",
        "ReminderRule", "Attachment", "WeatherDay", "TrainingSession", "ReferenceRangeSetting",
      ])
  }

  @Test("F-ARCH-08: Jedes Attribut ist optional oder hat einen Standardwert")
  func attributesAreOptionalOrDefaulted() {
    for entity in schema.entities {
      for attribute in entity.attributes {
        #expect(
          attribute.isOptional || attribute.defaultValue != nil,
          "\(entity.name).\(attribute.name) ist weder optional noch vorbelegt")
      }
    }
  }

  @Test("F-ARCH-08: Keine Unique-Constraints")
  func noUniqueConstraints() {
    for entity in schema.entities {
      #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name) hat #Unique")
      for attribute in entity.attributes {
        #expect(!attribute.isUnique, "\(entity.name).\(attribute.name) ist unique")
      }
    }
  }

  @Test("F-ARCH-08: Alle Beziehungen sind optional und haben eine Inverse")
  func relationshipsAreOptionalWithInverse() {
    for entity in schema.entities {
      for relationship in entity.relationships {
        let label = "\(entity.name).\(relationship.name)"
        #expect(relationship.isOptional, "\(label) ist nicht optional")
        #expect(relationship.inverseName != nil, "\(label) hat keine Inverse")
        #expect(relationship.deleteRule != .deny, "\(label) nutzt .deny (von CloudKit nicht unterstützt)")
      }
    }
  }

  @Test("F-ARCH-08: Große Binärdaten liegen im externen Speicher")
  func binaryDataUsesExternalStorage() {
    for entity in schema.entities {
      for attribute in entity.attributes where isBinary(attribute) {
        let label = "\(entity.name).\(attribute.name)"
        guard !inlineBinaryAttributes.contains(label) else { continue }
        #expect(attribute.options.contains(.externalStorage), "\(label) ohne .externalStorage")
      }
    }
  }

  @Test("F-TEIL-02: Jede Entität hat id, createdAt, updatedAt, createdBy, lastModifiedBy")
  func everyEntityHasBookkeepingFields() {
    let required: Set<String> = ["id", "createdAt", "updatedAt", "createdBy", "lastModifiedBy"]
    for entity in schema.entities {
      let names = Set(entity.attributes.map(\.name))
      #expect(required.isSubset(of: names), "\(entity.name) fehlt \(required.subtracting(names))")
    }
  }

  @Test("F-TEIL-01: Jede pferdebezogene Entität hängt direkt oder über eine Behandlung am Pferd")
  func horseIsRoot() {
    let masterData: Set<String> = ["Horse", "Stable", "Feed", "Contact", "WeatherDay"]
    let viaTreatment: Set<String> = ["Medication"]
    for entity in schema.entities where !masterData.contains(entity.name) {
      let targets = Set(entity.relationships.map(\.destination))
      if viaTreatment.contains(entity.name) {
        #expect(targets.contains("Treatment"), "\(entity.name) hängt nicht an Treatment")
      } else {
        #expect(targets.contains("Horse"), "\(entity.name) hängt nicht am Pferd")
      }
    }
  }

  @Test("F-ARCH-06: Alle Feature-Flags stehen auf false")
  func featureFlagsAreOff() {
    #expect(FeatureFlags.cloudSyncEnabled == false)
    #expect(FeatureFlags.sharedTrainingContainerEnabled == false)
    #expect(FeatureFlags.sharingEnabled == false)
    #expect(FeatureFlags.widgetsEnabled == false)
  }

  private func isBinary(_ attribute: Schema.Attribute) -> Bool {
    attribute.valueType == Data.self || attribute.valueType == Data?.self
  }
}

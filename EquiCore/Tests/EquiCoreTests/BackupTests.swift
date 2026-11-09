import Foundation
import SwiftData
import Testing

@testable import EquiCore

@Suite("Backup und Wiederherstellung (F-BACKUP, NF-06)")
struct BackupTests {
  private let now = Date(timeIntervalSince1970: 1_794_300_000)

  /// One record of every entity type with relationships and binary data.
  @discardableResult
  private func populate(_ container: ModelContainer) throws -> Horse {
    let context = ModelContext(container)
    let horse = Horse(name: "Luna", sortIndex: 0)
    horse.photoData = Data([0xFF, 0xD8, 0x01, 0x02])
    horse.isFoodProducingAnimal = true
    horse.birthDate = Date(timeIntervalSince1970: 1_400_000_000)
    context.insert(horse)
    let stable = Stable(name: "Hof Sonnenschein", latitude: 51.962, longitude: 7.625)
    stable.locality = "Münster"
    context.insert(stable)
    horse.move(to: stable, on: StableAssignment.unknownStart, in: context)
    context.insert(BodyMeasurement(horse: horse, type: .weight, value: 540.5, timestamp: now, method: .scale))
    horse.setReferenceRange(ReferenceRange(lower: 500, upper: 560), for: .weight, in: context)
    let hay = Feed(name: "Heu", category: .roughage, defaultUnit: .kilogram)
    context.insert(hay)
    horse.applyFeedingPlan(
      [FeedingPlanLine(feedID: hay.id, amount: 8, unit: .kilogram, meal: .adLibitum)], from: now, feeds: [hay],
      in: context)
    let log = FeedingLog(horse: horse, feed: hay, amount: 5, unit: .kilogram, timestamp: now)
    log.kind = .replacement
    log.meal = .adLibitum
    context.insert(log)
    let contact = Contact(name: "Dr. Weber", role: .veterinarian)
    contact.phone = "+49 251 123456"
    context.insert(contact)
    let condition = Condition(horse: horse, name: "Krampfkolik", diagnosedAt: now, isChronic: false)
    context.insert(condition)
    let treatment = Treatment(horse: horse, kind: .veterinarian, date: now)
    treatment.contact = contact
    treatment.condition = condition
    treatment.descriptionText = "Untersuchung; \"Kolik\"\nmit Zeilenumbruch"
    treatment.cost = 120.5
    context.insert(treatment)
    let medication = Medication(treatment: treatment, productName: "Flunixin")
    medication.foodWithdrawalDays = 5
    medication.vaccinationTargets = [.influenza]
    context.insert(medication)
    let symptom = SymptomEntry(horse: horse, category: .colic, severity: .severe, startDate: now)
    symptom.details = SymptomDetails(colic: .init(duration: 3600, signs: [.pawing], veterinarianCalled: true))
    symptom.condition = condition
    symptom.treatment = treatment
    context.insert(symptom)
    let photo = EquiCore.Attachment(
      fileData: Data(repeating: 7, count: 2048), contentType: "public.jpeg", title: "Foto")
    photo.symptom = symptom
    context.insert(photo)
    let pdf = EquiCore.Attachment(fileData: Data("%PDF-1.7".utf8), contentType: "com.adobe.pdf", title: "Befund")
    pdf.treatment = treatment
    context.insert(pdf)
    let rule = ReminderRule(
      horse: horse, kind: .vaccinationInfluenza, title: "Impfung Influenza", intervalValue: 6, intervalUnit: .months)
    rule.matchingTreatmentKind = .vaccination
    rule.matchingVaccinationTarget = .influenza
    rule.leadTimeDays = 14
    context.insert(rule)
    let session = TrainingSession(horse: horse, type: .dressage, start: now, duration: 3600)
    session.routeData = Data("[{\"latitude\":51.9}]".utf8)
    session.distance = 5000
    context.insert(session)
    try context.save()
    return horse
  }

  /// Arrays sorted by id, so documents from different fetch orders compare equal.
  private func normalized(_ document: BackupDocument) -> BackupDocument {
    var d = document
    d.horses.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.stables.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.stableAssignments.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.measurements.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.referenceRanges?.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.feeds.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.feedingPlanItems.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.feedingLogs.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.symptoms.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.conditions.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.treatments.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.medications.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.contacts.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.reminderRules.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.attachments.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    d.trainingSessions.sort { $0.meta.id.uuidString < $1.meta.id.uuidString }
    return d
  }

  private func temporaryURL() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "Test-\(UUID().uuidString).equibackup")
  }

  @Test("F-BACKUP-04: Roundtrip – Export, Datei schreiben und lesen, Import in leeren Store, Vergleich")
  func roundtrip() async throws {
    let source = try EquiModelContainer.make(inMemory: true)
    try populate(source)
    let package = try await BackupService(modelContainer: source).makePackage(appVersion: "0.1 (1)", now: now)
    #expect(package.document.schemaVersion == BackupDocument.currentSchemaVersion)
    #expect(package.document.appVersion == "0.1 (1)")
    #expect(package.document.exportedAt == now)
    #expect(package.files.count == 4, "Pferdefoto, Symptomfoto, PDF, Route")

    let url = temporaryURL()
    defer { try? FileManager.default.removeItem(at: url) }
    try package.fileWrapper().write(to: url, options: .atomic, originalContentsURL: nil)
    let read = try BackupPackage(url: url)
    #expect(FileManager.default.fileExists(atPath: url.appending(path: "backup.json").path()))

    let target = try EquiModelContainer.make(inMemory: true)
    let summary = try await BackupService(modelContainer: target).restore(read, mode: .replace)
    #expect(summary.inserted == package.document.recordCount)
    #expect(summary.skipped == 0)

    let again = try await BackupService(modelContainer: target).makePackage(appVersion: "0.1 (1)", now: now)
    // Compare with what was written: dates are stored with millisecond precision.
    let written = try BackupPackage.decoder.decode(
      BackupDocument.self, from: try BackupPackage.encoder.encode(package.document))
    #expect(normalized(again.document) == normalized(written))
    #expect(again.files == package.files)

    // Relationships survived.
    let context = ModelContext(target)
    let horse = try #require(try context.fetch(FetchDescriptor<Horse>()).first)
    #expect(horse.stableAssignment()?.stable?.name == "Hof Sonnenschein")
    #expect(horse.referenceRange(for: .weight) == ReferenceRange(lower: 500, upper: 560))
    let symptom = try #require(horse.symptoms?.first)
    #expect(symptom.treatment?.contact?.name == "Dr. Weber")
    #expect(symptom.details.colic?.signs == [.pawing])
    #expect(symptom.attachments?.first?.fileData?.count == 2048)
    #expect(horse.activeWithdrawals(on: now).count == 1)
  }

  @Test("F-BACKUP-03: Zusammenführen legt vorhandene Einträge nicht doppelt an")
  func mergeDoesNotDuplicate() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    try populate(container)
    let service = BackupService(modelContainer: container)
    let package = try await service.makePackage(appVersion: "test", now: now)

    let summary = try await service.restore(package, mode: .merge)
    #expect(summary.inserted == 0)
    #expect(summary.skipped == package.document.recordCount)
    let context = ModelContext(container)
    #expect(try context.fetchCount(FetchDescriptor<Horse>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<Medication>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<EquiCore.Attachment>()) == 2)

    // A second horse from another device is added, existing ones stay.
    let other = try EquiModelContainer.make(inMemory: true)
    let otherContext = ModelContext(other)
    otherContext.insert(Horse(name: "Max"))
    try otherContext.save()
    let otherPackage = try await BackupService(modelContainer: other).makePackage(appVersion: "test", now: now)
    _ = try await service.restore(otherPackage, mode: .merge)
    #expect(try ModelContext(container).fetch(FetchDescriptor<Horse>()).map(\.name).sorted() == ["Luna", "Max"])
  }

  @Test("F-BACKUP-03: Ersetzen löscht den bisherigen Bestand")
  func replaceRemovesCurrentData() async throws {
    let source = try EquiModelContainer.make(inMemory: true)
    try populate(source)
    let package = try await BackupService(modelContainer: source).makePackage(appVersion: "test", now: now)

    let target = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(target)
    context.insert(Horse(name: "Nur auf diesem Gerät"))
    context.insert(Feed(name: "Alter Hafer", category: .concentrate))
    try context.save()

    try await BackupService(modelContainer: target).restore(package, mode: .replace)
    let check = ModelContext(target)
    #expect(try check.fetch(FetchDescriptor<Horse>()).map(\.name) == ["Luna"])
    #expect(try check.fetch(FetchDescriptor<Feed>()).map(\.name) == ["Heu"])
  }

  @Test("F-BACKUP-04: Backup der Schemaversion 1 lässt sich importieren")
  func importsSchemaVersion1() async throws {
    let json = """
      {
        "schemaVersion": 1, "appVersion": "0.1 (1)", "exportedAt": "2026-11-01T10:00:00Z",
        "horses": [{"meta": {"id": "11111111-1111-1111-1111-111111111111", "createdAt": "2026-10-01T10:00:00Z",
          "updatedAt": "2026-10-01T10:00:00Z"}, "name": "Luna", "notes": "", "isArchived": false, "sortIndex": 0}],
        "stables": [], "stableAssignments": [], "measurements": [],
        "feeds": [{"meta": {"id": "22222222-2222-2222-2222-222222222222", "createdAt": "2026-10-01T10:00:00Z",
          "updatedAt": "2026-10-01T10:00:00Z"}, "name": "Hafer", "categoryRaw": "concentrate", "isArchived": false}],
        "feedingPlanItems": [],
        "feedingLogs": [{"meta": {"id": "33333333-3333-3333-3333-333333333333", "createdAt": "2026-10-02T10:00:00Z",
          "updatedAt": "2026-10-02T10:00:00Z"}, "horseID": "11111111-1111-1111-1111-111111111111",
          "feedID": "22222222-2222-2222-2222-222222222222", "amount": 0.5, "unitRaw": "kilogram",
          "timestamp": "2026-10-02T08:00:00Z", "note": ""}],
        "symptoms": [], "conditions": [], "treatments": [], "medications": [], "contacts": [],
        "reminderRules": [], "attachments": [], "trainingSessions": []
      }
      """
    let document = try BackupPackage.decoder.decode(BackupDocument.self, from: Data(json.utf8))
    #expect(document.referenceRanges == nil)
    let container = try EquiModelContainer.make(inMemory: true)
    let summary = try await BackupService(modelContainer: container).restore(
      BackupPackage(document: document), mode: .replace)
    #expect(summary.inserted == 3)
    let log = try #require(try ModelContext(container).fetch(FetchDescriptor<FeedingLog>()).first)
    #expect(log.kind == .extra, "Ältere Einträge sind Zusatzgaben")
    #expect(log.horse?.name == "Luna")
    #expect(log.feed?.name == "Hafer")
  }

  @Test("NF-06: Neuere Schemaversion und fehlende Dateien werden abgelehnt, ohne den Bestand zu ändern")
  func rejectsInvalidBackupsWithoutChanges() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    try populate(container)
    let service = BackupService(modelContainer: container)
    var package = try await service.makePackage(appVersion: "test", now: now)

    var newer = package
    newer.document.schemaVersion = BackupDocument.currentSchemaVersion + 1
    await #expect(throws: BackupError.unsupportedSchemaVersion(BackupDocument.currentSchemaVersion + 1)) {
      try await service.restore(newer, mode: .replace)
    }

    let missing = try #require(package.files.keys.sorted().first)
    package.files[missing] = nil
    await #expect(throws: BackupError.missingFile(missing)) {
      try await service.restore(package, mode: .replace)
    }

    let context = ModelContext(container)
    #expect(try context.fetchCount(FetchDescriptor<Horse>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<EquiCore.Attachment>()) == 2)
  }

  @Test("Datumsangaben behalten Millisekunden, ältere Dateien ohne Nachkommastellen bleiben lesbar")
  func datePrecision() throws {
    let date = Date(timeIntervalSince1970: 1_794_300_000.5)
    var document = BackupDocument(appVersion: "test", exportedAt: date)
    document.horses = []
    let decoded = try BackupPackage.decoder.decode(
      BackupDocument.self, from: try BackupPackage.encoder.encode(document))
    #expect(abs(decoded.exportedAt.timeIntervalSince(date)) < 0.001)
    let json = String(decoding: try BackupPackage.encoder.encode(document), as: UTF8.self)
    #expect(json.contains(".500Z"))
  }

  @Test("Ungültige Pakete werden erkannt")
  func invalidPackage() {
    #expect(throws: BackupError.invalidPackage) {
      try BackupPackage(fileWrapper: FileWrapper(directoryWithFileWrappers: [:]))
    }
    #expect(throws: BackupError.invalidPackage) {
      try BackupPackage(
        fileWrapper: FileWrapper(directoryWithFileWrappers: [
          "backup.json": FileWrapper(regularFileWithContents: Data("{}".utf8))
        ]))
    }
  }

  @Test("F-BACKUP-03: Vorschau zeigt Pferde und Anzahl der Einträge")
  func preview() async throws {
    let container = try EquiModelContainer.make(inMemory: true)
    try populate(container)
    let package = try await BackupService(modelContainer: container).makePackage(appVersion: "0.1 (1)", now: now)
    let preview = BackupPreview(package: package)
    #expect(preview.horseNames == ["Luna"])
    #expect(preview.entryCount == package.document.recordCount - 1)
    #expect(preview.fileCount == 4)
    #expect(preview.schemaVersion == 3)
  }
}

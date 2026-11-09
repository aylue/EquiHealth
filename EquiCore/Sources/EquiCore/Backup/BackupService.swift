import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Creates and restores backups off the main actor (F-BACKUP-01 to -04, NF-05, NF-06).
@ModelActor
public actor BackupService {
  // MARK: Export

  /// Snapshot of all user data except the weather cache, including photos and attachments.
  public func makePackage(appVersion: String, now: Date = .now) throws -> BackupPackage {
    var document = BackupDocument(appVersion: appVersion, exportedAt: now)
    var files: [String: Data] = [:]

    for horse in try fetchAll(Horse.self) {
      var photoFile: String?
      if let photo = horse.photoData {
        photoFile = "photos/\(horse.id.uuidString).jpg"
        files[photoFile!] = photo
      }
      document.horses.append(
        HorseRecord(
          meta: meta(horse), name: horse.name, callName: horse.callName, birthDate: horse.birthDate,
          breed: horse.breed, sexRaw: horse.sexRaw, color: horse.color, markings: horse.markings, ueln: horse.ueln,
          microchipNumber: horse.microchipNumber, isFoodProducingAnimal: horse.isFoodProducingAnimal,
          photoFile: photoFile, notes: horse.notes, isArchived: horse.isArchived, sortIndex: horse.sortIndex))
    }
    document.stables = try fetchAll(Stable.self).map {
      StableRecord(meta: meta($0), name: $0.name, locality: $0.locality, latitude: $0.latitude, longitude: $0.longitude)
    }
    document.stableAssignments = try fetchAll(StableAssignment.self).map {
      StableAssignmentRecord(
        meta: meta($0), horseID: $0.horse?.id, stableID: $0.stable?.id, validFrom: $0.validFrom,
        validUntil: $0.validUntil)
    }
    document.measurements = try fetchAll(BodyMeasurement.self).map {
      MeasurementRecord(
        meta: meta($0), horseID: $0.horse?.id, typeRaw: $0.typeRaw, value: $0.value, timestamp: $0.timestamp,
        methodRaw: $0.methodRaw, note: $0.note)
    }
    document.referenceRanges = try fetchAll(ReferenceRangeSetting.self).map {
      ReferenceRangeRecord(
        meta: meta($0), horseID: $0.horse?.id, measurementTypeRaw: $0.measurementTypeRaw, lower: $0.lower,
        upper: $0.upper)
    }
    document.feeds = try fetchAll(Feed.self).map {
      FeedRecord(
        meta: meta($0), name: $0.name, categoryRaw: $0.categoryRaw, manufacturer: $0.manufacturer,
        defaultUnitRaw: $0.defaultUnitRaw, isArchived: $0.isArchived)
    }
    document.feedingPlanItems = try fetchAll(FeedingPlanItem.self).map {
      FeedingPlanItemRecord(
        meta: meta($0), horseID: $0.horse?.id, feedID: $0.feed?.id, amount: $0.amount, unitRaw: $0.unitRaw,
        mealRaw: $0.mealRaw, validFrom: $0.validFrom, validUntil: $0.validUntil)
    }
    document.feedingLogs = try fetchAll(FeedingLog.self).map {
      FeedingLogRecord(
        meta: meta($0), horseID: $0.horse?.id, feedID: $0.feed?.id, amount: $0.amount, unitRaw: $0.unitRaw,
        timestamp: $0.timestamp, note: $0.note, kindRaw: $0.kindRaw, mealRaw: $0.mealRaw)
    }
    document.symptoms = try fetchAll(SymptomEntry.self).map {
      SymptomRecord(
        meta: meta($0), horseID: $0.horse?.id, conditionID: $0.condition?.id, treatmentID: $0.treatment?.id,
        categoryRaw: $0.categoryRaw, customCategoryName: $0.customCategoryName, severityRaw: $0.severityRaw,
        startDate: $0.startDate, endDate: $0.endDate, detailsData: $0.detailsData, note: $0.note)
    }
    document.conditions = try fetchAll(Condition.self).map {
      ConditionRecord(
        meta: meta($0), horseID: $0.horse?.id, name: $0.name, diagnosedAt: $0.diagnosedAt, healedAt: $0.healedAt,
        isChronic: $0.isChronic, diagnosedBy: $0.diagnosedBy, note: $0.note)
    }
    document.treatments = try fetchAll(Treatment.self).map {
      TreatmentRecord(
        meta: meta($0), horseID: $0.horse?.id, contactID: $0.contact?.id, conditionID: $0.condition?.id,
        kindRaw: $0.kindRaw, customKindName: $0.customKindName, date: $0.date, descriptionText: $0.descriptionText,
        cost: $0.cost, currencyCode: $0.currencyCode)
    }
    document.medications = try fetchAll(Medication.self).map {
      MedicationRecord(
        meta: meta($0), treatmentID: $0.treatment?.id, productName: $0.productName,
        activeIngredient: $0.activeIngredient, dose: $0.dose, doseUnit: $0.doseUnit, routeRaw: $0.routeRaw,
        startDate: $0.startDate, endDate: $0.endDate, frequency: $0.frequency, batchNumber: $0.batchNumber,
        foodWithdrawalUntil: $0.foodWithdrawalUntil, foodWithdrawalDays: $0.foodWithdrawalDays,
        competitionWithdrawalUntil: $0.competitionWithdrawalUntil,
        competitionWithdrawalDays: $0.competitionWithdrawalDays, vaccinationTargetsRaw: $0.vaccinationTargetsRaw,
        customVaccinationTarget: $0.customVaccinationTarget)
    }
    document.contacts = try fetchAll(Contact.self).map {
      ContactRecord(
        meta: meta($0), name: $0.name, roleRaw: $0.roleRaw, practice: $0.practice, phone: $0.phone,
        email: $0.email, address: $0.address)
    }
    document.reminderRules = try fetchAll(ReminderRule.self).map {
      ReminderRuleRecord(
        meta: meta($0), horseID: $0.horse?.id, kindRaw: $0.kindRaw, title: $0.title, intervalValue: $0.intervalValue,
        intervalUnitRaw: $0.intervalUnitRaw, leadTimeDays: $0.leadTimeDays, reminderHour: $0.reminderHour,
        reminderMinute: $0.reminderMinute, isActive: $0.isActive, startDate: $0.startDate,
        snoozedUntil: $0.snoozedUntil, matchingTreatmentKindRaw: $0.matchingTreatmentKindRaw,
        matchingVaccinationTargetRaw: $0.matchingVaccinationTargetRaw)
    }
    for attachment in try fetchAll(Attachment.self) {
      var file: String?
      if let data = attachment.fileData {
        let ext = UTType(attachment.contentType)?.preferredFilenameExtension ?? "bin"
        file = "attachments/\(attachment.id.uuidString).\(ext)"
        files[file!] = data
      }
      document.attachments.append(
        AttachmentRecord(
          meta: meta(attachment), horseID: attachment.horse?.id, symptomID: attachment.symptom?.id,
          treatmentID: attachment.treatment?.id, contentType: attachment.contentType, title: attachment.title,
          fileName: attachment.fileName, file: file))
    }
    for session in try fetchAll(TrainingSession.self) {
      var routeFile: String?
      if let route = session.routeData {
        routeFile = "routes/\(session.id.uuidString).json"
        files[routeFile!] = route
      }
      document.trainingSessions.append(
        TrainingSessionRecord(
          meta: meta(session), horseID: session.horse?.id, interfaceVersion: session.interfaceVersion,
          typeRaw: session.typeRaw, start: session.start, end: session.end, duration: session.duration,
          distance: session.distance, walkDuration: session.walkDuration, trotDuration: session.trotDuration,
          canterDuration: session.canterDuration, heartRateAverage: session.heartRateAverage,
          heartRateMax: session.heartRateMax, routeFile: routeFile, sourceApp: session.sourceApp, note: session.note))
    }
    return BackupPackage(document: document, files: files)
  }

  // MARK: Restore

  /// Restores `package` in one transaction: either everything is saved or nothing (NF-06).
  /// `merge` skips records whose UUID already exists (F-BACKUP-03).
  @discardableResult
  public func restore(_ package: BackupPackage, mode: BackupRestoreMode) throws -> BackupRestoreSummary {
    let document = package.document
    guard document.schemaVersion <= BackupDocument.currentSchemaVersion else {
      throw BackupError.unsupportedSchemaVersion(document.schemaVersion)
    }
    let referenced =
      document.horses.compactMap(\.photoFile) + document.attachments.compactMap(\.file)
      + document.trainingSessions.compactMap(\.routeFile)
    if let missing = referenced.first(where: { package.files[$0] == nil }) {
      throw BackupError.missingFile(missing)
    }

    do {
      if mode == .replace { try deleteAllUserData() }
      var importer = Importer(context: modelContext, files: package.files, mergeWithExisting: mode == .merge)
      try importer.run(document)
      try modelContext.save()
      return BackupRestoreSummary(inserted: importer.inserted, skipped: importer.skipped)
    } catch {
      modelContext.rollback()
      throw error
    }
  }

  private func deleteAllUserData() throws {
    // Horses cascade to all horse-related records; shared master data is deleted separately.
    for horse in try fetchAll(Horse.self) { modelContext.delete(horse) }
    for stable in try fetchAll(Stable.self) { modelContext.delete(stable) }
    for feed in try fetchAll(Feed.self) { modelContext.delete(feed) }
    for contact in try fetchAll(Contact.self) { modelContext.delete(contact) }
    // No save here: deletion and import are committed together or rolled back together (NF-06).
  }

  private func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
    try modelContext.fetch(FetchDescriptor<T>())
  }

  private func meta(_ record: some EquiRecord) -> RecordMeta {
    RecordMeta(
      id: record.id, createdAt: record.createdAt, updatedAt: record.updatedAt, createdBy: record.createdBy,
      lastModifiedBy: record.lastModifiedBy)
  }
}

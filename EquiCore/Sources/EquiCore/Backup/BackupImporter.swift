import Foundation
import SwiftData

/// Inserts backup records and links their relationships. Used inside one transaction by
/// `BackupService.restore`.
struct Importer {
  let context: ModelContext
  let files: [String: Data]
  let mergeWithExisting: Bool

  private(set) var inserted = 0
  private(set) var skipped = 0

  private var horses: [UUID: Horse] = [:]
  private var stables: [UUID: Stable] = [:]
  private var feeds: [UUID: Feed] = [:]
  private var contacts: [UUID: Contact] = [:]
  private var conditions: [UUID: Condition] = [:]
  private var treatments: [UUID: Treatment] = [:]
  private var symptoms: [UUID: SymptomEntry] = [:]

  init(context: ModelContext, files: [String: Data], mergeWithExisting: Bool) {
    self.context = context
    self.files = files
    self.mergeWithExisting = mergeWithExisting
  }

  mutating func run(_ document: BackupDocument) throws {
    // Objects referenced by others first, so relationships can be linked right away.
    horses = try existing(Horse.self)
    stables = try existing(Stable.self)
    feeds = try existing(Feed.self)
    contacts = try existing(Contact.self)
    conditions = try existing(Condition.self)
    treatments = try existing(Treatment.self)
    symptoms = try existing(SymptomEntry.self)

    for record in document.horses where shouldInsert(record.meta.id, in: horses) {
      let horse = Horse(name: record.name, sortIndex: record.sortIndex)
      apply(record.meta, to: horse)
      horse.callName = record.callName
      horse.birthDate = record.birthDate
      horse.breed = record.breed
      horse.sexRaw = record.sexRaw
      horse.color = record.color
      horse.markings = record.markings
      horse.ueln = record.ueln
      horse.microchipNumber = record.microchipNumber
      horse.isFoodProducingAnimal = record.isFoodProducingAnimal
      horse.photoData = record.photoFile.flatMap { files[$0] }
      horse.notes = record.notes
      horse.isArchived = record.isArchived
      insert(horse)
      horses[horse.id] = horse
    }
    for record in document.stables where shouldInsert(record.meta.id, in: stables) {
      let stable = Stable(name: record.name, latitude: record.latitude, longitude: record.longitude)
      apply(record.meta, to: stable)
      stable.locality = record.locality
      insert(stable)
      stables[stable.id] = stable
    }
    for record in document.feeds where shouldInsert(record.meta.id, in: feeds) {
      let feed = Feed(name: record.name, category: .other)
      apply(record.meta, to: feed)
      feed.categoryRaw = record.categoryRaw
      feed.manufacturer = record.manufacturer
      feed.defaultUnitRaw = record.defaultUnitRaw
      feed.isArchived = record.isArchived
      insert(feed)
      feeds[feed.id] = feed
    }
    for record in document.contacts where shouldInsert(record.meta.id, in: contacts) {
      let contact = Contact(name: record.name, role: .other)
      apply(record.meta, to: contact)
      contact.roleRaw = record.roleRaw
      contact.practice = record.practice
      contact.phone = record.phone
      contact.email = record.email
      contact.address = record.address
      insert(contact)
      contacts[contact.id] = contact
    }
    for record in document.conditions where shouldInsert(record.meta.id, in: conditions) {
      let condition = Condition(horse: horse(record.horseID), name: record.name)
      apply(record.meta, to: condition)
      condition.diagnosedAt = record.diagnosedAt
      condition.healedAt = record.healedAt
      condition.isChronic = record.isChronic
      condition.diagnosedBy = record.diagnosedBy
      condition.note = record.note
      insert(condition)
      conditions[condition.id] = condition
    }
    for record in document.treatments where shouldInsert(record.meta.id, in: treatments) {
      let treatment = Treatment(horse: horse(record.horseID), kind: .other, date: record.date)
      apply(record.meta, to: treatment)
      treatment.kindRaw = record.kindRaw
      treatment.customKindName = record.customKindName
      treatment.descriptionText = record.descriptionText
      treatment.cost = record.cost
      treatment.currencyCode = record.currencyCode
      treatment.contact = record.contactID.flatMap { contacts[$0] }
      treatment.condition = record.conditionID.flatMap { conditions[$0] }
      insert(treatment)
      treatments[treatment.id] = treatment
    }
    for record in document.symptoms where shouldInsert(record.meta.id, in: symptoms) {
      let symptom = SymptomEntry(horse: horse(record.horseID), category: .other, severity: .mild)
      apply(record.meta, to: symptom)
      symptom.categoryRaw = record.categoryRaw
      symptom.customCategoryName = record.customCategoryName
      symptom.severityRaw = record.severityRaw
      symptom.startDate = record.startDate
      symptom.endDate = record.endDate
      symptom.detailsData = record.detailsData
      symptom.note = record.note
      symptom.condition = record.conditionID.flatMap { conditions[$0] }
      symptom.treatment = record.treatmentID.flatMap { treatments[$0] }
      insert(symptom)
      symptoms[symptom.id] = symptom
    }

    // Leaf records: nothing references them.
    let existingAssignments = try existingIDs(StableAssignment.self)
    for record in document.stableAssignments where shouldInsert(record.meta.id, in: existingAssignments) {
      let assignment = StableAssignment(
        horse: horse(record.horseID), stable: record.stableID.flatMap { stables[$0] }, validFrom: record.validFrom,
        validUntil: record.validUntil)
      apply(record.meta, to: assignment)
      insert(assignment)
    }
    let existingMeasurements = try existingIDs(BodyMeasurement.self)
    for record in document.measurements where shouldInsert(record.meta.id, in: existingMeasurements) {
      let measurement = BodyMeasurement(
        horse: horse(record.horseID), type: .weight, value: record.value, timestamp: record.timestamp)
      apply(record.meta, to: measurement)
      measurement.typeRaw = record.typeRaw
      measurement.methodRaw = record.methodRaw
      measurement.note = record.note
      insert(measurement)
    }
    let existingRanges = try existingIDs(ReferenceRangeSetting.self)
    for record in document.referenceRanges ?? [] where shouldInsert(record.meta.id, in: existingRanges) {
      let setting = ReferenceRangeSetting(
        horse: horse(record.horseID), type: .weight, range: ReferenceRange(lower: record.lower, upper: record.upper))
      apply(record.meta, to: setting)
      setting.measurementTypeRaw = record.measurementTypeRaw
      insert(setting)
    }
    let existingPlanItems = try existingIDs(FeedingPlanItem.self)
    for record in document.feedingPlanItems where shouldInsert(record.meta.id, in: existingPlanItems) {
      let item = FeedingPlanItem(
        horse: horse(record.horseID), feed: record.feedID.flatMap { feeds[$0] }, amount: record.amount,
        unit: .kilogram, meal: .morning, validFrom: record.validFrom)
      apply(record.meta, to: item)
      item.unitRaw = record.unitRaw
      item.mealRaw = record.mealRaw
      item.validUntil = record.validUntil
      insert(item)
    }
    let existingLogs = try existingIDs(FeedingLog.self)
    for record in document.feedingLogs where shouldInsert(record.meta.id, in: existingLogs) {
      let log = FeedingLog(
        horse: horse(record.horseID), feed: record.feedID.flatMap { feeds[$0] }, amount: record.amount,
        unit: .kilogram, timestamp: record.timestamp)
      apply(record.meta, to: log)
      log.unitRaw = record.unitRaw
      log.note = record.note
      log.kindRaw = record.kindRaw ?? FeedingLogKind.extra.rawValue
      log.mealRaw = record.mealRaw
      insert(log)
    }
    let existingMedications = try existingIDs(Medication.self)
    for record in document.medications where shouldInsert(record.meta.id, in: existingMedications) {
      let medication = Medication(
        treatment: record.treatmentID.flatMap { treatments[$0] }, productName: record.productName)
      apply(record.meta, to: medication)
      medication.activeIngredient = record.activeIngredient
      medication.dose = record.dose
      medication.doseUnit = record.doseUnit
      medication.routeRaw = record.routeRaw
      medication.startDate = record.startDate
      medication.endDate = record.endDate
      medication.frequency = record.frequency
      medication.batchNumber = record.batchNumber
      medication.foodWithdrawalUntil = record.foodWithdrawalUntil
      medication.foodWithdrawalDays = record.foodWithdrawalDays
      medication.competitionWithdrawalUntil = record.competitionWithdrawalUntil
      medication.competitionWithdrawalDays = record.competitionWithdrawalDays
      medication.vaccinationTargetsRaw = record.vaccinationTargetsRaw
      medication.customVaccinationTarget = record.customVaccinationTarget
      insert(medication)
    }
    let existingRules = try existingIDs(ReminderRule.self)
    for record in document.reminderRules where shouldInsert(record.meta.id, in: existingRules) {
      let rule = ReminderRule(
        horse: horse(record.horseID), kind: .custom, title: record.title, intervalValue: record.intervalValue,
        intervalUnit: .months)
      apply(record.meta, to: rule)
      rule.kindRaw = record.kindRaw
      rule.intervalUnitRaw = record.intervalUnitRaw
      rule.leadTimeDays = record.leadTimeDays
      rule.reminderHour = record.reminderHour
      rule.reminderMinute = record.reminderMinute
      rule.isActive = record.isActive
      rule.startDate = record.startDate
      rule.snoozedUntil = record.snoozedUntil
      rule.matchingTreatmentKindRaw = record.matchingTreatmentKindRaw
      rule.matchingVaccinationTargetRaw = record.matchingVaccinationTargetRaw
      insert(rule)
    }
    let existingAttachments = try existingIDs(Attachment.self)
    for record in document.attachments where shouldInsert(record.meta.id, in: existingAttachments) {
      let attachment = Attachment(
        fileData: record.file.flatMap { files[$0] }, contentType: record.contentType, title: record.title)
      apply(record.meta, to: attachment)
      attachment.fileName = record.fileName
      attachment.horse = horse(record.horseID)
      attachment.symptom = record.symptomID.flatMap { symptoms[$0] }
      attachment.treatment = record.treatmentID.flatMap { treatments[$0] }
      insert(attachment)
    }
    let existingSessions = try existingIDs(TrainingSession.self)
    for record in document.trainingSessions where shouldInsert(record.meta.id, in: existingSessions) {
      let session = TrainingSession(
        horse: horse(record.horseID), type: .other, start: record.start, duration: record.duration)
      apply(record.meta, to: session)
      session.interfaceVersion = record.interfaceVersion
      session.typeRaw = record.typeRaw
      session.end = record.end
      session.distance = record.distance
      session.walkDuration = record.walkDuration
      session.trotDuration = record.trotDuration
      session.canterDuration = record.canterDuration
      session.heartRateAverage = record.heartRateAverage
      session.heartRateMax = record.heartRateMax
      session.routeData = record.routeFile.flatMap { files[$0] }
      session.sourceApp = record.sourceApp
      session.note = record.note
      insert(session)
    }
  }

  // MARK: Helpers

  private func horse(_ id: UUID?) -> Horse? {
    id.flatMap { horses[$0] }
  }

  private mutating func shouldInsert<Value>(_ id: UUID, in existing: [UUID: Value]) -> Bool {
    if existing[id] != nil {
      skipped += 1
      return false
    }
    return true
  }

  private mutating func shouldInsert(_ id: UUID, in existing: Set<UUID>) -> Bool {
    if existing.contains(id) {
      skipped += 1
      return false
    }
    return true
  }

  private mutating func insert(_ model: some PersistentModel) {
    context.insert(model)
    inserted += 1
  }

  /// Keeps the identity and bookkeeping of the backup (merge decides by UUID, F-BACKUP-03).
  private func apply(_ meta: RecordMeta, to record: some EquiRecord) {
    record.id = meta.id
    record.createdAt = meta.createdAt
    record.updatedAt = meta.updatedAt
    record.createdBy = meta.createdBy
    record.lastModifiedBy = meta.lastModifiedBy
  }

  /// Existing objects by UUID; empty when not merging (replace mode deleted them in this transaction).
  private func existing<T: EquiRecord>(_ type: T.Type) throws -> [UUID: T] {
    guard mergeWithExisting else { return [:] }
    let all = try context.fetch(FetchDescriptor<T>())
    return Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }

  private func existingIDs<T: EquiRecord>(_ type: T.Type) throws -> Set<UUID> {
    Set(try existing(type).keys)
  }
}

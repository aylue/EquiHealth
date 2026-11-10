import Foundation
import SwiftData

/// All records that belong to one horse: the unit that will be shared with other Apple accounts
/// (F-TEIL-01, F-TEIL-03).
///
/// The horse is the root. Every entry hangs on it directly, or through a treatment or symptom
/// (medications, attachments). Master data (stables, feeds, contacts) is referenced, not owned, and
/// can be used by several horses and later by several people; it is listed separately.
public struct HorseRecordGraph {
  public let horse: Horse
  /// Records owned by the horse, without the horse itself.
  public let ownedRecords: [any EquiRecord]
  /// Master data the owned records refer to.
  public let referencedMasterData: [any EquiRecord]

  public init(horse: Horse) {
    self.horse = horse
    var owned: [any EquiRecord] = []
    var seen = Set<UUID>()
    func add(_ record: any EquiRecord) {
      if seen.insert(record.id).inserted { owned.append(record) }
    }
    for record in horse.stableAssignments ?? [] { add(record) }
    for record in horse.measurements ?? [] { add(record) }
    for record in horse.referenceRanges ?? [] { add(record) }
    for record in horse.feedingPlanItems ?? [] { add(record) }
    for record in horse.feedingLogs ?? [] { add(record) }
    for record in horse.conditions ?? [] { add(record) }
    for record in horse.reminderRules ?? [] { add(record) }
    for record in horse.trainingSessions ?? [] { add(record) }
    for record in horse.attachments ?? [] { add(record) }
    for symptom in horse.symptoms ?? [] {
      add(symptom)
      for attachment in symptom.attachments ?? [] { add(attachment) }
    }
    for treatment in horse.treatments ?? [] {
      add(treatment)
      for medication in treatment.medications ?? [] { add(medication) }
      for attachment in treatment.attachments ?? [] { add(attachment) }
    }
    ownedRecords = owned

    var master: [any EquiRecord] = []
    var seenMaster = Set<UUID>()
    func addMaster(_ record: (any EquiRecord)?) {
      if let record, seenMaster.insert(record.id).inserted { master.append(record) }
    }
    for assignment in horse.stableAssignments ?? [] { addMaster(assignment.stable) }
    for item in horse.feedingPlanItems ?? [] { addMaster(item.feed) }
    for log in horse.feedingLogs ?? [] { addMaster(log.feed) }
    for treatment in horse.treatments ?? [] { addMaster(treatment.contact) }
    referencedMasterData = master
  }

  public var recordCount: Int { ownedRecords.count + 1 }
}

import Foundation
import SwiftData

/// Generates a large, realistic test data set for performance checks (NF-04): by default 10 horses
/// over 10 years, about 50,000 entries. Runs off the main actor and saves in batches.
///
/// Values are arbitrary test data, not medical reference values.
@ModelActor
public actor LargeDataGenerator {
  /// Marker in `Horse.notes` of generated horses, so they can be removed again.
  public static let marker = "[Testdaten NF-04]"

  public struct Summary: Sendable, Equatable {
    public var horses: Int
    public var entries: Int
  }

  @discardableResult
  public func generate(horses horseCount: Int = 10, years: Int = 10, now: Date = .now, seed: UInt64 = 2026)
    throws -> Summary
  {
    var random = SeededRandom(seed: seed)
    let calendar = Calendar(identifier: .gregorian)
    let end = calendar.startOfDay(for: now)
    guard let start = calendar.date(byAdding: .year, value: -years, to: end) else {
      return Summary(horses: 0, entries: 0)
    }
    var entries = 0
    var pending = 0
    func inserted(_ count: Int = 1) throws {
      entries += count
      pending += count
      if pending >= 5_000 {
        try modelContext.save()
        pending = 0
      }
    }
    func day(_ offset: Int, hour: Int = 9) -> Date {
      let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
      return calendar.date(bySettingHour: hour, minute: Int(random.next() % 60), second: 0, of: date) ?? date
    }
    func uniform(_ range: ClosedRange<Double>) -> Double {
      range.lowerBound + (range.upperBound - range.lowerBound) * Double(random.next() % 10_000) / 10_000
    }
    let totalDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0

    let hay = Feed(name: "Heu (Test)", category: .roughage, defaultUnit: .kilogram)
    let oats = Feed(name: "Hafer (Test)", category: .concentrate, defaultUnit: .gram)
    let mineral = Feed(name: "Mineralfutter (Test)", category: .mineral, defaultUnit: .gram)
    let vet = Contact(name: "Tierarztpraxis (Test)", role: .veterinarian)
    let farrier = Contact(name: "Hufschmied (Test)", role: .farrier)
    for model in [hay, oats, mineral] as [any PersistentModel] { modelContext.insert(model) }
    modelContext.insert(vet)
    modelContext.insert(farrier)
    let stable = Stable(name: "Teststall", latitude: 51.95, longitude: 7.99)
    modelContext.insert(stable)
    try inserted(6)

    let existing = try modelContext.fetchCount(FetchDescriptor<Horse>())
    let symptomCategories: [SymptomCategory] = [.cough, .muscleStiffness, .colic, .lameness, .diarrhea, .skinChange]
    let trainingTypes: [TrainingType] = [.dressage, .jumping, .hacking, .lunging, .groundwork, .riding]

    for index in 0..<horseCount {
      let horse = Horse(name: "Testpferd \(index + 1)", sortIndex: existing + index)
      horse.notes = Self.marker
      horse.birthDate = calendar.date(byAdding: .year, value: -(years + 3 + index % 8), to: end)
      modelContext.insert(horse)
      let assignment = StableAssignment(horse: horse, stable: stable, validFrom: StableAssignment.unknownStart)
      modelContext.insert(assignment)
      try inserted(2)

      // Measurements: weight weekly, temperature every 2 days, pulse/respiration monthly, girth quarterly.
      var weight = uniform(480...620)
      for offset in stride(from: 0, to: totalDays, by: 7) {
        weight = min(700, max(400, weight + uniform(-4...4)))
        modelContext.insert(
          BodyMeasurement(horse: horse, type: .weight, value: weight.rounded(), timestamp: day(offset), method: .scale))
        try inserted()
      }
      for offset in stride(from: 1, to: totalDays, by: 2) {
        modelContext.insert(
          BodyMeasurement(
            horse: horse, type: .bodyTemperature, value: (uniform(37.2...38.2) * 10).rounded() / 10,
            timestamp: day(offset, hour: 7), method: .thermometer))
        try inserted()
      }
      for offset in stride(from: 2, to: totalDays, by: 30) {
        modelContext.insert(
          BodyMeasurement(horse: horse, type: .pulse, value: uniform(28...44).rounded(), timestamp: day(offset)))
        modelContext.insert(
          BodyMeasurement(
            horse: horse, type: .respiratoryRate, value: uniform(8...16).rounded(), timestamp: day(offset)))
        try inserted(2)
      }
      for offset in stride(from: 5, to: totalDays, by: 91) {
        modelContext.insert(
          BodyMeasurement(
            horse: horse, type: .bellyGirth, value: uniform(190...210).rounded(), timestamp: day(offset),
            method: .measuringTape))
        try inserted()
      }

      // Feeding plan: a new version every 6 months with 3 positions; extras twice a week.
      for offset in stride(from: 0, to: totalDays, by: 182) {
        let from = calendar.startOfDay(for: day(offset))
        let until = calendar.date(byAdding: .day, value: 182, to: from)
        for (feed, amount, unit, meal) in [
          (hay, uniform(7...10).rounded(), FeedUnit.kilogram, Meal.adLibitum),
          (oats, uniform(300...800).rounded(), FeedUnit.gram, Meal.morning),
          (mineral, uniform(50...100).rounded(), FeedUnit.gram, Meal.evening),
        ] {
          let item = FeedingPlanItem(horse: horse, feed: feed, amount: amount, unit: unit, meal: meal, validFrom: from)
          item.validUntil = offset + 182 < totalDays ? until : nil
          modelContext.insert(item)
          try inserted()
        }
      }
      for offset in stride(from: 3, to: totalDays, by: 2) where random.next() % 7 < 5 {
        let log = FeedingLog(
          horse: horse, feed: oats, amount: uniform(100...300).rounded(), unit: .gram, timestamp: day(offset, hour: 17))
        if random.next() % 10 == 0 { log.note = "Zusatzgabe nach dem Training" }
        modelContext.insert(log)
        try inserted()
      }

      // Health: about 20 symptoms per year, some with a treatment and medication.
      for offset in stride(from: 10, to: totalDays, by: 18) {
        let category = symptomCategories[Int(random.next() % UInt64(symptomCategories.count))]
        let symptom = SymptomEntry(
          horse: horse, category: category, severity: [.mild, .moderate, .severe][Int(random.next() % 3)],
          startDate: day(offset))
        symptom.endDate = day(offset + 2 + Int(random.next() % 10))
        symptom.note = "Beobachtung \(offset / 18 + 1)"
        modelContext.insert(symptom)
        try inserted()
        if random.next() % 4 == 0 {
          let treatment = Treatment(horse: horse, kind: .veterinarian, date: day(offset + 1, hour: 11))
          treatment.contact = vet
          treatment.descriptionText = "Untersuchung wegen \(category.rawValue)"
          treatment.cost = uniform(60...250).rounded()
          symptom.treatment = treatment
          modelContext.insert(treatment)
          let medication = Medication(treatment: treatment, productName: "Testpräparat \(random.next() % 20)")
          medication.dose = uniform(5...20).rounded()
          medication.doseUnit = "ml"
          medication.foodWithdrawalDays = Int(random.next() % 28)
          modelContext.insert(medication)
          try inserted(2)
        }
      }
      for offset in stride(from: 20, to: totalDays, by: 42) {
        let treatment = Treatment(horse: horse, kind: .farrier, date: day(offset, hour: 14))
        treatment.contact = farrier
        treatment.descriptionText = "Beschlag"
        modelContext.insert(treatment)
        try inserted()
      }
      for offset in stride(from: 30, to: totalDays, by: 182) {
        let treatment = Treatment(horse: horse, kind: .vaccination, date: day(offset, hour: 10))
        treatment.contact = vet
        modelContext.insert(treatment)
        let vaccine = Medication(treatment: treatment, productName: "Testimpfstoff")
        vaccine.vaccinationTargets = [.influenza, .tetanus]
        modelContext.insert(vaccine)
        try inserted(2)
      }
      let rule = ReminderRule(
        horse: horse, kind: .vaccinationInfluenza, title: "Impfung Influenza", intervalValue: 6, intervalUnit: .months)
      rule.matchingTreatmentKind = .vaccination
      rule.matchingVaccinationTarget = .influenza
      rule.leadTimeDays = 14
      modelContext.insert(rule)
      try inserted()

      // Training: three sessions a week, without routes (routes are covered by the sample generator).
      for offset in stride(from: 0, to: totalDays, by: 2) where random.next() % 7 < 3 {
        let minutes = uniform(25...75).rounded()
        let session = TrainingSession(
          horse: horse, type: trainingTypes[Int(random.next() % UInt64(trainingTypes.count))],
          start: day(offset, hour: 15), duration: minutes * 60)
        session.walkDuration = (minutes * 60 * 0.5).rounded()
        session.trotDuration = (minutes * 60 * 0.35).rounded()
        session.canterDuration = minutes * 60 - session.walkDuration! - session.trotDuration!
        session.sourceApp = TrainingInterface.sampleSourceApp
        modelContext.insert(session)
        try inserted()
      }
    }
    try modelContext.save()
    return Summary(horses: horseCount, entries: entries)
  }

  /// Deletes generated horses (with all their entries) and the generated master data.
  public func removeGeneratedData() throws {
    let marker = Self.marker
    for horse in try modelContext.fetch(FetchDescriptor<Horse>(predicate: #Predicate { $0.notes == marker })) {
      modelContext.delete(horse)
    }
    for feed in try modelContext.fetch(FetchDescriptor<Feed>()) where feed.name.hasSuffix("(Test)") {
      modelContext.delete(feed)
    }
    for contact in try modelContext.fetch(FetchDescriptor<Contact>()) where contact.name.hasSuffix("(Test)") {
      modelContext.delete(contact)
    }
    for stable in try modelContext.fetch(FetchDescriptor<Stable>(predicate: #Predicate { $0.name == "Teststall" })) {
      modelContext.delete(stable)
    }
    try modelContext.save()
  }
}

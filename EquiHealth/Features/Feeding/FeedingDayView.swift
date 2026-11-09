import EquiCore
import SwiftData
import SwiftUI

/// "Fütterung an Tag X": the plan valid that day plus deviations and extras (F-FUTTER-05).
struct FeedingDayView: View {
  @Environment(\.modelContext) private var modelContext
  let horse: Horse
  @State private var date: Date
  @State private var editingLog: FeedingLog?
  @State private var showsNewLog = false

  init(horse: Horse, date: Date = .now) {
    self.horse = horse
    _date = State(initialValue: date)
  }

  var body: some View {
    // Noon avoids daylight-saving edge cases when moving day by day.
    let dayMoment = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    let plan = horse.feedingPlan(at: dayMoment)
    let logs = horse.feedingLogs(onDayOf: date)
    let totals = horse.dailyFeedTotals(from: date, through: date)

    List {
      Section {
        HStack {
          Button("Vorheriger Tag", systemImage: "chevron.left") { move(by: -1) }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("day.previous")
          Spacer()
          DatePicker("Tag", selection: $date, displayedComponents: .date)
            .labelsHidden()
            .accessibilityIdentifier("day.date")
          Spacer()
          Button("Nächster Tag", systemImage: "chevron.right") { move(by: 1) }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("day.next")
        }
      }

      if plan.isEmpty {
        Section("Plan") {
          Text("An diesem Tag galt kein Futterplan.").foregroundStyle(.secondary)
        }
      } else {
        FeedingPlanSections(items: plan)
      }

      Section {
        ForEach(logs) { log in
          Button {
            editingLog = log
          } label: {
            FeedingLogRow(log: log)
          }
          .foregroundStyle(.primary)
        }
        .onDelete { offsets in
          for index in offsets { modelContext.delete(logs[index]) }
          try? modelContext.save()
        }
        Button("Abweichung oder Zusatzgabe", systemImage: "plus") { showsNewLog = true }
          .accessibilityIdentifier("day.addLog")
      } header: {
        Text("Abweichungen und Zusatzgaben")
      }

      if !totals.isEmpty {
        Section {
          ForEach(totals, id: \.category) { total in
            LabeledContent(total.category.title, value: FeedUnit.kilogram.format(total.kilograms))
          }
        } header: {
          Text("Tagesmenge")
        } footer: {
          Text("Nur Mengen in kg und g. Liter, Messbecher und Scheiben lassen sich nicht in kg umrechnen.")
        }
      }
    }
    .navigationTitle("Fütterung an Tag X")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $editingLog) { log in
      FeedingLogFormView(horse: horse, log: log, date: log.timestamp)
    }
    .sheet(isPresented: $showsNewLog) {
      FeedingLogFormView(horse: horse, log: nil, date: date)
    }
  }

  private func move(by days: Int) {
    if let newDate = Calendar.current.date(byAdding: .day, value: days, to: date) {
      date = newDate
    }
  }
}

struct FeedingLogRow: View {
  let log: FeedingLog

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(log.feed?.name ?? String(localized: "Gelöschtes Futtermittel"))
        Text(log.timestamp.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
        if !log.note.isEmpty {
          Text(log.note).font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      Text(log.unit.format(log.amount)).monospacedDigit()
    }
    .accessibilityElement(children: .combine)
  }
}

/// Record a deviating or additional feeding (F-FUTTER-04).
struct FeedingLogFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let horse: Horse
  let log: FeedingLog?

  @Query(sort: \Feed.name) private var allFeeds: [Feed]
  @State private var feedID: UUID?
  @State private var amountText: String
  @State private var unit: FeedUnit
  @State private var timestamp: Date
  @State private var note: String

  init(horse: Horse, log: FeedingLog?, date: Date = .now) {
    self.horse = horse
    self.log = log
    _feedID = State(initialValue: log?.feed?.id)
    _amountText = State(initialValue: log.map { $0.amount.formatted(.number.grouping(.never)) } ?? "")
    _unit = State(initialValue: log?.unit ?? .kilogram)
    let defaultTime =
      Calendar.current.isDateInToday(date)
      ? Date.now : (Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
    _timestamp = State(initialValue: log?.timestamp ?? defaultTime)
    _note = State(initialValue: log?.note ?? "")
  }

  private var feeds: [Feed] { allFeeds.filter { !$0.isArchived || $0.id == feedID } }
  private var amount: Double? { DecimalInput.parse(amountText) }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Futtermittel", selection: $feedID) {
            Text("Bitte wählen").tag(UUID?.none)
            ForEach(feeds) { feed in
              Text(feed.name).tag(Optional(feed.id))
            }
          }
          HStack {
            TextField("Menge", text: $amountText)
              .keyboardType(.decimalPad)
              .accessibilityIdentifier("log.amount")
            Picker("Einheit", selection: $unit) {
              ForEach(FeedUnit.allCases, id: \.self) { unit in
                Text(unit.symbol).tag(unit)
              }
            }
            .labelsHidden()
          }
          DatePicker("Zeitpunkt", selection: $timestamp)
        } header: {
          Text(horse.name)
        } footer: {
          Text("Zum Beispiel eine Zusatzgabe oder eine einmalige Abweichung vom Plan. Erscheint zusätzlich zum Plan.")
        }
        Section("Notiz") {
          TextField("Notiz", text: $note, axis: .vertical)
        }
      }
      .navigationTitle(log == nil ? "Zusatzgabe erfassen" : "Eintrag bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(feedID == nil || amount == nil)
            .accessibilityIdentifier("save")
        }
      }
      .onChange(of: feedID) { _, newID in
        if log == nil, let defaultUnit = allFeeds.first(where: { $0.id == newID })?.defaultUnit {
          unit = defaultUnit
        }
      }
    }
  }

  private func save() {
    guard let amount, let feed = allFeeds.first(where: { $0.id == feedID }) else { return }
    let target = log ?? FeedingLog(horse: horse, feed: feed, amount: amount, unit: unit, timestamp: timestamp)
    if log == nil { modelContext.insert(target) }
    target.feed = feed
    target.amount = amount
    target.unit = unit
    target.timestamp = timestamp
    target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    target.touch()
    try? modelContext.save()
    dismiss()
  }
}

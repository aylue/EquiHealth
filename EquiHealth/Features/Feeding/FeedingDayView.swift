import EquiCore
import SwiftData
import SwiftUI

/// "Fütterung an Tag X": the plan valid that day with its deviations, plus extras (F-FUTTER-05, Q-033).
struct FeedingDayView: View {
  @Environment(\.modelContext) private var modelContext
  let horse: Horse
  @State private var date: Date
  @State private var editingLog: FeedingLog?
  @State private var showsNewLog = false
  @State private var changingAmount: FeedingDayEntry?

  init(horse: Horse, date: Date = .now) {
    self.horse = horse
    _date = State(initialValue: date)
  }

  var body: some View {
    let entries = horse.feedingDay(date)
    let extras = horse.extraFeedingLogs(onDayOf: date)
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

      if entries.isEmpty {
        Section("Plan") {
          Text("An diesem Tag galt kein Futterplan.").foregroundStyle(.secondary)
        }
      } else {
        ForEach(Meal.allCases, id: \.self) { meal in
          let mealEntries = entries.filter { $0.planItem.meal == meal }
          if !mealEntries.isEmpty {
            Section(meal.title) {
              ForEach(mealEntries) { entry in
                entryRow(entry)
              }
            }
          }
        }
      }

      Section {
        ForEach(extras) { log in
          Button {
            editingLog = log
          } label: {
            FeedingLogRow(log: log)
          }
          .foregroundStyle(.primary)
        }
        .onDelete { offsets in
          for index in offsets { modelContext.delete(extras[index]) }
          try? modelContext.save()
        }
        Button("Zusatzgabe erfassen", systemImage: "plus") { showsNewLog = true }
          .accessibilityIdentifier("day.addLog")
      } header: {
        Text("Zusatzgaben")
      } footer: {
        if !entries.isEmpty {
          Text("Tippe auf eine Planposition, um sie für diesen Tag auszulassen oder eine andere Menge zu erfassen.")
        }
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
    .sheet(item: $changingAmount) { entry in
      DeviationAmountSheet(entry: entry) { amount, unit in
        horse.setFeedingDeviation(for: entry.planItem, on: date, amount: amount, unit: unit, in: modelContext)
        try? modelContext.save()
      }
    }
  }

  /// Plan position with today's deviation; tap or swipe to change it (Q-033).
  private func entryRow(_ entry: FeedingDayEntry) -> some View {
    Menu {
      Button("Andere Menge", systemImage: "pencil") { changingAmount = entry }
      if !entry.isOmitted {
        Button("Heute auslassen", systemImage: "minus.circle") { omit(entry) }
      }
      if entry.deviation != nil {
        Button("Wie geplant", systemImage: "arrow.uturn.backward") { reset(entry) }
      }
    } label: {
      FeedingDayEntryRow(entry: entry)
    }
    .foregroundStyle(.primary)
    .swipeActions {
      if entry.deviation != nil {
        Button("Wie geplant", systemImage: "arrow.uturn.backward") { reset(entry) }
      } else {
        Button("Auslassen", systemImage: "minus.circle") { omit(entry) }
      }
    }
    .accessibilityIdentifier("day.entry")
  }

  private func omit(_ entry: FeedingDayEntry) {
    horse.setFeedingDeviation(
      for: entry.planItem, on: date, amount: nil, unit: entry.planItem.unit, in: modelContext)
    try? modelContext.save()
  }

  private func reset(_ entry: FeedingDayEntry) {
    horse.clearFeedingDeviation(for: entry.planItem, on: date, in: modelContext)
    try? modelContext.save()
  }

  private func move(by days: Int) {
    if let newDate = Calendar.current.date(byAdding: .day, value: days, to: date) {
      date = newDate
    }
  }
}

/// Plan position of one day; shows a changed amount or that it was left out (Q-033).
struct FeedingDayEntryRow: View {
  let entry: FeedingDayEntry

  var body: some View {
    let item = entry.planItem
    HStack(spacing: 12) {
      Image(systemName: item.feed?.category.systemImage ?? "leaf")
        .foregroundStyle(Color.categoryFeeding)
        .frame(width: 28)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(item.feed?.name ?? String(localized: "Gelöschtes Futtermittel"))
          .strikethrough(entry.isOmitted)
        if entry.isOmitted {
          Text("heute ausgelassen").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        } else if entry.deviation != nil {
          Text("Plan: \(item.unit.format(item.amount))").font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      Text(entry.effectiveUnit.format(entry.effectiveAmount))
        .monospacedDigit()
        .strikethrough(entry.isOmitted)
        .foregroundStyle(entry.deviation == nil ? .secondary : .primary)
        .fontWeight(entry.deviation == nil ? .regular : .semibold)
    }
    .accessibilityElement(children: .combine)
  }
}

/// Enter the amount actually fed for one plan position on one day (Q-033).
struct DeviationAmountSheet: View {
  @Environment(\.dismiss) private var dismiss
  let entry: FeedingDayEntry
  let onSave: (Double, FeedUnit) -> Void

  @State private var amountText: String
  @State private var unit: FeedUnit

  init(entry: FeedingDayEntry, onSave: @escaping (Double, FeedUnit) -> Void) {
    self.entry = entry
    self.onSave = onSave
    let initial = entry.isOmitted ? entry.planItem.amount : entry.effectiveAmount
    _amountText = State(initialValue: initial.formatted(.number.grouping(.never)))
    _unit = State(initialValue: entry.effectiveUnit)
  }

  private var amount: Double? {
    DecimalInput.parse(amountText).flatMap { $0 >= 0 ? $0 : nil }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            TextField("Menge", text: $amountText)
              .keyboardType(.decimalPad)
              .accessibilityIdentifier("deviation.amount")
            Picker("Einheit", selection: $unit) {
              ForEach(FeedUnit.allCases, id: \.self) { unit in
                Text(unit.symbol).tag(unit)
              }
            }
            .labelsHidden()
          }
        } header: {
          Text(entry.planItem.feed?.name ?? "")
        } footer: {
          Text("Laut Plan: \(entry.planItem.unit.format(entry.planItem.amount)). Gilt nur für diesen Tag.")
        }
      }
      .navigationTitle("Andere Menge")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") {
            if let amount { onSave(amount, unit) }
            dismiss()
          }
          .disabled(amount == nil)
          .accessibilityIdentifier("deviation.save")
        }
      }
    }
    .presentationDetents([.medium])
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
          Text(
            "Wird zusätzlich zum Plan gezählt. Eine Planposition auslassen oder ändern kannst du in „Fütterung an Tag X“ direkt an der Position."
          )
        }
        Section("Notiz") {
          TextField("Notiz", text: $note, axis: .vertical)
        }
      }
      .navigationTitle(log == nil ? "Zusatzgabe erfassen" : "Zusatzgabe bearbeiten")
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

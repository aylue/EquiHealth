import EquiCore
import SwiftData
import SwiftUI

/// Current feeding plan of a horse with its versions (F-FUTTER-02, F-FUTTER-03).
struct FeedingPlanView: View {
  let horse: Horse
  @State private var showsEditor = false

  var body: some View {
    let plan = horse.feedingPlan(at: .now)
    List {
      if plan.isEmpty {
        ContentUnavailableView {
          Label("Kein Futterplan", systemImage: "list.clipboard")
        } description: {
          Text("Lege fest, was \(horse.name) zu welcher Mahlzeit bekommt.")
        } actions: {
          Button("Plan anlegen") { showsEditor = true }
            .buttonStyle(.borderedProminent)
        }
      } else {
        FeedingPlanSections(items: plan)
      }
      let versions = horse.feedingPlanVersionDates
      if !versions.isEmpty {
        Section {
          ForEach(versions, id: \.self) { date in
            NavigationLink {
              FeedingDayView(horse: horse, date: date)
            } label: {
              Text("gültig ab \(date.formatted(date: .long, time: .omitted))")
            }
          }
        } header: {
          Text("Versionen")
        } footer: {
          Text(
            "Jede Änderung legt eine neue Version an. So bleibt nachvollziehbar, was \(horse.name) an einem Tag bekam.")
        }
      }
    }
    .navigationTitle("Futterplan")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(plan.isEmpty ? "Plan anlegen" : "Plan ändern") { showsEditor = true }
          .accessibilityIdentifier("plan.edit")
      }
    }
    .sheet(isPresented: $showsEditor) {
      FeedingPlanEditor(horse: horse)
    }
  }
}

/// Plan items grouped by meal.
struct FeedingPlanSections: View {
  let items: [FeedingPlanItem]

  var body: some View {
    ForEach(Meal.allCases, id: \.self) { meal in
      let mealItems = items.filter { $0.meal == meal }
      if !mealItems.isEmpty {
        Section(meal.title) {
          ForEach(mealItems) { item in
            LabeledContent {
              Text(item.unit.format(item.amount)).monospacedDigit()
            } label: {
              Label {
                Text(item.feed?.name ?? String(localized: "Gelöschtes Futtermittel"))
              } icon: {
                Image(systemName: item.feed?.category.systemImage ?? "leaf")
                  .foregroundStyle(Color.categoryFeeding)
              }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("plan.item")
          }
        }
      }
    }
  }
}

/// Edits the plan as a whole; saving creates a new version valid from the chosen date (F-FUTTER-03).
struct FeedingPlanEditor: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let horse: Horse

  @Query(sort: \Feed.name) private var allFeeds: [Feed]
  @State private var validFrom = Date.now
  @State private var lines: [LineDraft]
  @State private var showsNewFeed = false

  struct LineDraft: Identifiable {
    let id = UUID()
    var feedID: UUID?
    var amountText: String
    var unit: FeedUnit
    var meal: Meal
  }

  init(horse: Horse) {
    self.horse = horse
    _lines = State(
      initialValue: horse.feedingPlan(at: .now).map { item in
        LineDraft(
          feedID: item.feed?.id, amountText: item.amount.formatted(.number.grouping(.never)), unit: item.unit,
          meal: item.meal)
      })
  }

  private var selectableFeeds: [Feed] { allFeeds.filter { !$0.isArchived } }

  private var planLines: [FeedingPlanLine]? {
    var result: [FeedingPlanLine] = []
    for line in lines {
      guard let feedID = line.feedID, let amount = DecimalInput.parse(line.amountText), amount > 0 else {
        return nil
      }
      result.append(FeedingPlanLine(feedID: feedID, amount: amount, unit: line.unit, meal: line.meal))
    }
    return result
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          DatePicker("Gültig ab", selection: $validFrom, displayedComponents: .date)
            .accessibilityIdentifier("plan.validFrom")
        } footer: {
          Text("Bis zu diesem Tag bleibt der bisherige Plan erhalten.")
        }

        if selectableFeeds.isEmpty {
          Section {
            Text("Noch keine Futtermittel angelegt.").foregroundStyle(.secondary)
            Button("Futtermittel anlegen", systemImage: "plus") { showsNewFeed = true }
          }
        }

        ForEach(Meal.allCases, id: \.self) { meal in
          Section(meal.title) {
            ForEach($lines) { $line in
              if line.meal == meal {
                lineEditor($line)
              }
            }
            .onDelete { offsets in
              let mealLines = lines.filter { $0.meal == meal }
              let ids = Set(offsets.map { mealLines[$0].id })
              lines.removeAll { ids.contains($0.id) }
            }
            Button("Futtermittel hinzufügen", systemImage: "plus") { addLine(meal: meal) }
              .disabled(selectableFeeds.isEmpty)
              .accessibilityIdentifier("plan.addLine.\(meal.rawValue)")
          }
        }
      }
      .navigationTitle("Futterplan ändern")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(planLines == nil)
            .accessibilityIdentifier("plan.save")
        }
      }
      .sheet(isPresented: $showsNewFeed) {
        FeedFormView(feed: nil)
      }
    }
  }

  private func lineEditor(_ line: Binding<LineDraft>) -> some View {
    VStack(alignment: .leading) {
      Picker("Futtermittel", selection: line.feedID) {
        Text("Bitte wählen").tag(UUID?.none)
        ForEach(selectableFeeds) { feed in
          Text(feed.name).tag(Optional(feed.id))
        }
      }
      .accessibilityIdentifier("plan.feed")
      HStack {
        TextField("Menge", text: line.amountText)
          .keyboardType(.decimalPad)
          .accessibilityLabel(Text("Menge"))
          .accessibilityIdentifier("plan.amount")
        Picker("Einheit", selection: line.unit) {
          ForEach(FeedUnit.allCases, id: \.self) { unit in
            Text(unit.symbol).tag(unit)
          }
        }
        .labelsHidden()
      }
    }
    .onChange(of: line.wrappedValue.feedID) { _, feedID in
      if let unit = allFeeds.first(where: { $0.id == feedID })?.defaultUnit {
        line.wrappedValue.unit = unit
      }
    }
  }

  private func addLine(meal: Meal) {
    let feed = selectableFeeds.first
    lines.append(LineDraft(feedID: feed?.id, amountText: "", unit: feed?.defaultUnit ?? .kilogram, meal: meal))
  }

  private func save() {
    guard let planLines else { return }
    horse.applyFeedingPlan(planLines, from: validFrom, feeds: allFeeds, in: modelContext)
    try? modelContext.save()
    dismiss()
  }
}

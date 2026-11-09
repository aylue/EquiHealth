import EquiCore
import SwiftData
import SwiftUI

/// Feed master data shared by all horses: create, edit, archive (F-FUTTER-01, F-TEIL-01).
struct FeedsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Feed.name) private var feeds: [Feed]
  @State private var editing: FeedEditTarget?

  var body: some View {
    let active = feeds.filter { !$0.isArchived }
    let archived = feeds.filter(\.isArchived)
    List {
      if feeds.isEmpty {
        ContentUnavailableView {
          Label("Keine Futtermittel", systemImage: "leaf")
        } description: {
          Text("Lege Heu, Kraftfutter, Mineralfutter und Zusätze einmal an. Sie gelten für alle Pferde.")
        } actions: {
          Button("Futtermittel anlegen") { editing = .new }
            .buttonStyle(.borderedProminent)
        }
      }
      ForEach(FeedCategory.allCases, id: \.self) { category in
        let group = active.filter { $0.category == category }
        if !group.isEmpty {
          Section(category.title) {
            ForEach(group) { feed in
              row(feed)
                .swipeActions {
                  Button("Archivieren", systemImage: "archivebox") { setArchived(feed, true) }
                }
            }
          }
        }
      }
      if !archived.isEmpty {
        Section {
          ForEach(archived) { feed in
            row(feed)
              .swipeActions {
                Button("Wiederherstellen", systemImage: "arrow.uturn.backward") { setArchived(feed, false) }
              }
          }
        } header: {
          Text("Archiviert")
        } footer: {
          Text(
            "Archivierte Futtermittel stehen in neuen Plänen nicht zur Auswahl. Bisherige Einträge bleiben erhalten.")
        }
      }
    }
    .navigationTitle("Futtermittel")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Futtermittel hinzufügen", systemImage: "plus") { editing = .new }
          .accessibilityIdentifier("feeds.add")
      }
    }
    .sheet(item: $editing) { target in
      FeedFormView(feed: target.feed)
    }
  }

  private func row(_ feed: Feed) -> some View {
    Button {
      editing = .existing(feed)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: feed.category.systemImage)
          .foregroundStyle(Color.categoryFeeding)
          .frame(width: 28)
          .accessibilityHidden(true)
        VStack(alignment: .leading) {
          Text(feed.name).foregroundStyle(.primary)
          let details = [feed.manufacturer, feed.defaultUnit?.title].compactMap { $0 }
          if !details.isEmpty {
            Text(details.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func setArchived(_ feed: Feed, _ archived: Bool) {
    feed.isArchived = archived
    feed.touch()
    try? modelContext.save()
  }
}

enum FeedEditTarget: Identifiable {
  case new
  case existing(Feed)

  var id: String {
    switch self {
    case .new: "new"
    case .existing(let feed): feed.id.uuidString
    }
  }

  var feed: Feed? {
    if case .existing(let feed) = self { return feed }
    return nil
  }
}

/// Create or edit a feed.
struct FeedFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let feed: Feed?
  var onCreate: ((Feed) -> Void)?

  @State private var name: String
  @State private var category: FeedCategory
  @State private var manufacturer: String
  @State private var defaultUnit: FeedUnit

  init(feed: Feed?, onCreate: ((Feed) -> Void)? = nil) {
    self.feed = feed
    self.onCreate = onCreate
    _name = State(initialValue: feed?.name ?? "")
    _category = State(initialValue: feed?.category ?? .roughage)
    _manufacturer = State(initialValue: feed?.manufacturer ?? "")
    _defaultUnit = State(initialValue: feed?.defaultUnit ?? .kilogram)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
            .accessibilityIdentifier("feed.name")
          Picker("Kategorie", selection: $category) {
            ForEach(FeedCategory.allCases, id: \.self) { category in
              Label(category.title, systemImage: category.systemImage).tag(category)
            }
          }
          .accessibilityIdentifier("feed.category")
          TextField("Hersteller", text: $manufacturer)
          Picker("Standardeinheit", selection: $defaultUnit) {
            ForEach(FeedUnit.allCases, id: \.self) { unit in
              Text(unit.title).tag(unit)
            }
          }
        }
      }
      .navigationTitle(feed == nil ? "Neues Futtermittel" : "Futtermittel bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(name.nilIfBlank == nil)
            .accessibilityIdentifier("feed.save")
        }
      }
    }
  }

  private func save() {
    guard let trimmed = name.nilIfBlank else { return }
    let target = feed ?? Feed(name: trimmed, category: category)
    if feed == nil { modelContext.insert(target) }
    target.name = trimmed
    target.category = category
    target.manufacturer = manufacturer.nilIfBlank
    target.defaultUnit = defaultUnit
    target.touch()
    try? modelContext.save()
    if feed == nil { onCreate?(target) }
    dismiss()
  }
}

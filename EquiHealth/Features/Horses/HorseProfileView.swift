import EquiCore
import SwiftData
import SwiftUI

/// Profile of one horse: photo, master data, age, current stable, latest values (F-PFERD-03).
struct HorseProfileView: View {
  @Bindable var horse: Horse
  @State private var showsEditor = false
  @State private var showsStableAssignment = false

  var body: some View {
    List {
      Section {
        VStack(spacing: 8) {
          HorseAvatar(photoData: horse.photoData, size: 120)
          Text(horse.name).font(.title.bold())
          if let callName = horse.callName {
            Text(callName).foregroundStyle(.secondary)
          }
          if horse.isArchived {
            Label("Archiviert", systemImage: "archivebox").font(.footnote).foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
      }
      .listRowBackground(Color.clear)

      if !horse.activeWithdrawals().isEmpty {
        Section("Warte- und Karenzzeiten") {
          WithdrawalNoticeRows(horse: horse)
        }
      }

      if !horse.chronicConditions.isEmpty {
        Section("Chronische Erkrankungen") {
          ForEach(horse.chronicConditions) { condition in
            NavigationLink {
              ConditionDetailView(condition: condition)
            } label: {
              ConditionRow(condition: condition)
            }
          }
        }
      }

      Section("Stammdaten") {
        if let birthDate = horse.birthDate {
          if let age = HorseAge.components(birthDate: birthDate) {
            LabeledContent("Alter", value: Self.ageFormatter.string(from: age) ?? "")
          }
          LabeledContent("Geburtsdatum", value: birthDate.formatted(date: .long, time: .omitted))
        }
        optionalRow("Rasse", horse.breed)
        optionalRow("Geschlecht", horse.sex?.title)
        optionalRow("Farbe", horse.color)
        optionalRow("Abzeichen", horse.markings)
        optionalRow("UELN", horse.ueln)
        optionalRow("Chipnummer", horse.microchipNumber)
        if let isFoodProducing = horse.isFoodProducingAnimal {
          LabeledContent("Schlachttier", value: isFoodProducing ? String(localized: "Ja") : String(localized: "Nein"))
        }
      }

      stableSection
      latestValuesSection

      Section {
        NavigationLink {
          HealthTimelineView(horse: horse)
        } label: {
          Label("Zeitleiste", systemImage: "list.bullet.below.rectangle")
        }
      }

      if !horse.notes.isEmpty {
        Section("Notizen") {
          Text(horse.notes)
        }
      }
    }
    .navigationTitle(horse.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Bearbeiten") { showsEditor = true }
      }
    }
    .sheet(isPresented: $showsEditor) {
      HorseFormView(horse: horse)
    }
    .sheet(isPresented: $showsStableAssignment) {
      StableAssignmentForm(horse: horse)
    }
  }

  private var stableSection: some View {
    Section("Stall") {
      if let current = horse.stableAssignment(), let stable = current.stable {
        LabeledContent {
          Text("seit \(current.validFrom.formatted(date: .abbreviated, time: .omitted))")
        } label: {
          Label(stable.name, systemImage: "house")
        }
      } else {
        Text("Kein Stall zugeordnet").foregroundStyle(.secondary)
      }
      Button(horse.stableAssignment() == nil ? "Stall zuordnen" : "Umzug erfassen", systemImage: "arrow.right.circle") {
        showsStableAssignment = true
      }
      let history = (horse.stableAssignments ?? []).filter { $0.validUntil != nil }
        .sorted { $0.validFrom > $1.validFrom }
      if !history.isEmpty {
        DisclosureGroup("Frühere Ställe") {
          ForEach(history) { assignment in
            LabeledContent(assignment.stable?.name ?? String(localized: "Gelöschter Stall")) {
              Text(
                (assignment.validFrom..<(assignment.validUntil ?? .now)).formatted(
                  .interval.day().month(.abbreviated).year()))
            }
          }
        }
      }
    }
  }

  private var latestValuesSection: some View {
    let latest = MeasurementType.allCases.compactMap { type in
      horse.latestMeasurement(of: type).map { (type, $0) }
    }
    return Section("Jüngste Werte") {
      if latest.isEmpty {
        Text("Noch keine Messwerte").foregroundStyle(.secondary)
      }
      ForEach(latest, id: \.0) { type, measurement in
        NavigationLink {
          MeasurementDetailView(horse: horse, type: type)
        } label: {
          LabeledContent {
            VStack(alignment: .trailing) {
              Text(type.format(measurement.value)).monospacedDigit()
              Text(measurement.timestamp.formatted(date: .abbreviated, time: .omitted)).font(.caption)
            }
          } label: {
            Label(type.title, systemImage: type.systemImage)
          }
        }
      }
    }
  }

  @ViewBuilder private func optionalRow(_ title: LocalizedStringKey, _ value: String?) -> some View {
    if let value {
      LabeledContent(title, value: value)
    }
  }

  private static var ageFormatter: DateComponentsFormatter {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.year, .month]
    formatter.unitsStyle = .full
    formatter.zeroFormattingBehavior = .dropAll
    return formatter
  }
}

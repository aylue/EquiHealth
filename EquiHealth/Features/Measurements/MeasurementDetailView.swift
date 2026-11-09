import Charts
import EquiCore
import SwiftData
import SwiftUI

/// Detail view of one measurement type, like in Apple Health (F-MESS-03, F-UI-03):
/// big current value, range picker, chart, list of all entries (edit, swipe to delete).
struct MeasurementDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AppState.self) private var appState

  let horse: Horse
  let type: MeasurementType

  /// All entries of this type, newest first.
  @Query private var measurements: [BodyMeasurement]
  @State private var range = ChartTimeRange.month
  @State private var selectedDate: Date?
  @State private var editing: BodyMeasurement?
  @State private var showsReferenceEditor = false

  init(horse: Horse, type: MeasurementType) {
    self.horse = horse
    self.type = type
    let horseID = horse.id
    let typeRaw = type.rawValue
    _measurements = Query(
      filter: #Predicate<BodyMeasurement> { $0.horse?.id == horseID && $0.typeRaw == typeRaw },
      sort: \BodyMeasurement.timestamp, order: .reverse)
  }

  private var referenceRange: ReferenceRange? {
    appState.referenceRange(for: type, horseID: horse.id)
  }

  private var domain: DateInterval {
    range.domain(for: measurements.map(\.timestamp))
  }

  private var visible: [BodyMeasurement] {
    measurements.filter { domain.contains($0.timestamp) }.reversed()
  }

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 12) {
          Picker("Zeitraum", selection: $range) {
            ForEach(ChartTimeRange.allCases) { range in
              Text(range.shortTitle)
                .accessibilityLabel(range.accessibilityTitle)
                .tag(range)
            }
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("chartRange")

          header

          if visible.isEmpty {
            Text("Keine Werte in diesem Zeitraum")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, minHeight: 200)
          } else {
            MeasurementChart(
              type: type, measurements: visible, domain: domain, referenceRange: referenceRange,
              selectedDate: $selectedDate
            )
            .frame(height: 240)
            .accessibilityIdentifier("measurementChart")
          }
          legend
        }
        .padding(.vertical, 4)
      }

      Section {
        Button(
          referenceRange == nil ? "Referenzbereich festlegen" : "Referenzbereich bearbeiten",
          systemImage: "slider.horizontal.below.rectangle"
        ) {
          showsReferenceEditor = true
        }
      } footer: {
        if let referenceRange {
          Text("Dein Bereich: \(type.format(referenceRange.lower)) – \(type.format(referenceRange.upper))")
        }
      }

      Section("Alle Einträge") {
        if measurements.isEmpty {
          Text("Noch keine Einträge").foregroundStyle(.secondary)
        }
        ForEach(measurements) { measurement in
          Button {
            editing = measurement
          } label: {
            MeasurementRow(type: type, measurement: measurement, referenceRange: referenceRange)
          }
          .foregroundStyle(.primary)
        }
        .onDelete(perform: delete)
      }
    }
    .navigationTitle(type.title)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("\(type.title) hinzufügen", systemImage: "plus") { appState.sheet = .newMeasurement(type) }
      }
    }
    .sheet(item: $editing) { measurement in
      MeasurementEntryView(horse: horse, type: type, existing: measurement)
    }
    .sheet(isPresented: $showsReferenceEditor) {
      ReferenceRangeEditor(horse: horse, type: type)
    }
    .onChange(of: range) { selectedDate = nil }
  }

  @ViewBuilder private var header: some View {
    if let latest = visible.last ?? measurements.first {
      VStack(alignment: .leading, spacing: 2) {
        Text(visible.isEmpty ? "Letzter Wert" : "Jüngster Wert im Zeitraum")
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(type.format(latest.value))
            .font(.largeTitle.bold().monospacedDigit())
          if latest.isEstimated {
            Text("geschätzt").font(.subheadline).foregroundStyle(.secondary)
          }
        }
        Text(latest.timestamp.formatted(date: .long, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("measurement.latest")
    }
  }

  @ViewBuilder private var legend: some View {
    if visible.contains(where: \.isEstimated) || referenceRange != nil {
      HStack(spacing: 16) {
        Label {
          Text("gemessen")
        } icon: {
          PointSymbol(isEstimated: false, isOutOfRange: false)
        }
        if visible.contains(where: \.isEstimated) {
          Label {
            Text("geschätzt")
          } icon: {
            PointSymbol(isEstimated: true, isOutOfRange: false)
          }
        }
        if referenceRange != nil {
          Label {
            Text("außerhalb")
          } icon: {
            PointSymbol(isEstimated: false, isOutOfRange: true)
          }
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityHidden(true)
    }
  }

  private func delete(at offsets: IndexSet) {
    for index in offsets {
      modelContext.delete(measurements[index])
    }
    try? modelContext.save()
  }
}

/// One entry in a measurement list, with "geschätzt" marker (F-MESS-09) and out-of-range marker (F-MESS-04).
struct MeasurementRow: View {
  let type: MeasurementType
  let measurement: BodyMeasurement
  let referenceRange: ReferenceRange?

  var body: some View {
    let isOutOfRange = referenceRange.map { !$0.contains(measurement.value) } ?? false
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(type.format(measurement.value)).monospacedDigit()
          if measurement.isEstimated {
            Text("geschätzt")
              .font(.caption)
              .padding(.horizontal, 6)
              .padding(.vertical, 1)
              .background(.fill.tertiary, in: .capsule)
          }
        }
        Text(measurement.timestamp.formatted(date: .abbreviated, time: .shortened))
          .font(.caption)
          .foregroundStyle(.secondary)
        if !measurement.note.isEmpty {
          Text(measurement.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
      }
      Spacer()
      if isOutOfRange {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.red)
          .accessibilityLabel(Text("außerhalb des Referenzbereichs"))
      }
      if let method = measurement.method, !measurement.isEstimated {
        Text(method.title).font(.caption).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

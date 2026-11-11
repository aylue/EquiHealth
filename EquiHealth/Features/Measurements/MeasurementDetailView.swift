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
  /// F-MESS-05: air temperature below the body temperature chart.
  @AppStorage("showsAirTemperature") private var showsAirTemperature = false

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
    horse.referenceRange(for: type)
  }

  var body: some View {
    // Computed once per update; with thousands of values this matters (NF-04).
    let domain = range.domain(for: measurements.map(\.timestamp))
    let visible = Array(measurements.filter { domain.contains($0.timestamp) }.reversed())
    let points = ChartSeries.points(
      from: visible.map { .init(date: $0.timestamp, value: $0.value, isEstimated: $0.isEstimated) }, domain: domain)
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

          header(visible: visible)

          if visible.isEmpty {
            Text("Keine Werte in diesem Zeitraum")
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, minHeight: 200)
          } else {
            MeasurementChart(
              type: type, points: points, domain: domain, referenceRange: referenceRange,
              selectedDate: $selectedDate
            )
            .frame(height: 240)
            .accessibilityIdentifier("measurementChart")
          }
          legend(visible: visible, points: points)
        }
        .padding(.vertical, 4)
      }

      if type == .bodyTemperature {
        Section {
          Toggle("Lufttemperatur einblenden", isOn: $showsAirTemperature.animation())
            .accessibilityIdentifier("measurement.airTemperature")
          if showsAirTemperature {
            AirTemperatureChart(horse: horse, domain: domain)
          }
        } footer: {
          if showsAirTemperature {
            Text("Tagesmittel und Spanne am Stall des jeweiligen Tages. \(WeatherService.attribution)")
          }
        }
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

  @ViewBuilder private func header(visible: [BodyMeasurement]) -> some View {
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

  @ViewBuilder private func legend(visible: [BodyMeasurement], points: [ChartPoint]) -> some View {
    if points.contains(where: \.isSummary) {
      Text("Über \(visible.count) Werte: Punkt = Mittelwert, Balken = Spanne je Abschnitt")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("chart.summaryNote")
    }
    if visible.contains(where: \.isEstimated) || referenceRange != nil {
      HStack(spacing: 16) {
        legendItem("gemessen", PointSymbol(isEstimated: false, isOutOfRange: false))
        if visible.contains(where: \.isEstimated) {
          legendItem("geschätzt", PointSymbol(isEstimated: true, isOutOfRange: false))
        }
        if referenceRange != nil {
          legendItem("außerhalb", PointSymbol(isEstimated: false, isOutOfRange: true))
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityHidden(true)
    }
  }

  private func legendItem(_ title: LocalizedStringKey, _ symbol: PointSymbol) -> some View {
    HStack(spacing: 4) {
      symbol
      Text(title)
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
    AdaptiveStack {
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
      AdaptiveSpacer()
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

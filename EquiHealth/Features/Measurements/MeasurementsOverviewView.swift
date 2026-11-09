import Charts
import EquiCore
import SwiftUI

/// All measurement types of a horse with their latest value (entry point from "Durchsuchen").
struct MeasurementsOverviewView: View {
  let horse: Horse

  var body: some View {
    List(MeasurementType.allCases) { type in
      NavigationLink {
        MeasurementDetailView(horse: horse, type: type)
      } label: {
        LabeledContent {
          if let latest = horse.latestMeasurement(of: type) {
            Text(type.format(latest.value)).monospacedDigit()
          } else {
            Text("–")
          }
        } label: {
          Label {
            Text(type.title)
          } icon: {
            Image(systemName: type.systemImage).foregroundStyle(Color.categoryMeasurements)
          }
        }
      }
      .accessibilityIdentifier("measurementType.\(type.rawValue)")
    }
    .navigationTitle("Messwerte")
  }
}

/// Small chart of the last 30 days for summary cards.
struct MeasurementSparkline: View {
  let type: MeasurementType
  let measurements: [BodyMeasurement]

  var body: some View {
    Chart(measurements) { measurement in
      LineMark(x: .value("Zeitpunkt", measurement.timestamp), y: .value(type.title, measurement.value))
        .foregroundStyle(Color.categoryMeasurements)
        .interpolationMethod(.monotone)
      PointMark(x: .value("Zeitpunkt", measurement.timestamp), y: .value(type.title, measurement.value))
        .symbol { PointSymbol(isEstimated: measurement.isEstimated, isOutOfRange: false) }
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: .automatic(includesZero: false))
    .accessibilityHidden(true)
  }
}

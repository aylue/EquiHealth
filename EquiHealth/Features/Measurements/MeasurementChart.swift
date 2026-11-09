import Charts
import EquiCore
import SwiftUI

/// Chart of one measurement type (F-MESS-03, F-MESS-04, F-MESS-09, F-UI-03).
/// Reference band, filled points for measured and hollow points for estimated values,
/// out-of-range points highlighted, selection gesture for single values.
struct MeasurementChart: View {
  let type: MeasurementType
  /// Values in ascending time order.
  let measurements: [BodyMeasurement]
  let domain: DateInterval
  let referenceRange: ReferenceRange?
  @Binding var selectedDate: Date?

  private var selected: BodyMeasurement? {
    guard let selectedDate else { return nil }
    return measurements.min {
      abs($0.timestamp.timeIntervalSince(selectedDate)) < abs($1.timestamp.timeIntervalSince(selectedDate))
    }
  }

  var body: some View {
    Chart {
      if let referenceRange {
        RectangleMark(
          xStart: .value("Beginn", domain.start),
          xEnd: .value("Ende", domain.end),
          yStart: .value("Untergrenze", referenceRange.lower),
          yEnd: .value("Obergrenze", referenceRange.upper)
        )
        .foregroundStyle(Color.categoryMeasurements.opacity(0.15))
        .accessibilityLabel(Text("Referenzbereich"))
        .accessibilityValue(Text("\(type.format(referenceRange.lower)) bis \(type.format(referenceRange.upper))"))
      }
      ForEach(measurements) { measurement in
        LineMark(
          x: .value("Zeitpunkt", measurement.timestamp),
          y: .value(type.title, measurement.value)
        )
        .foregroundStyle(Color.categoryMeasurements)
        .interpolationMethod(.monotone)
        .accessibilityHidden(true)

        PointMark(
          x: .value("Zeitpunkt", measurement.timestamp),
          y: .value(type.title, measurement.value)
        )
        .symbol {
          PointSymbol(isEstimated: measurement.isEstimated, isOutOfRange: isOutOfRange(measurement))
        }
        .accessibilityLabel(Text(measurement.timestamp.formatted(date: .abbreviated, time: .shortened)))
        .accessibilityValue(Text(accessibilityValue(measurement)))
      }
      if let selected {
        RuleMark(x: .value("Auswahl", selected.timestamp))
          .foregroundStyle(.secondary)
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
          .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
            VStack(alignment: .leading, spacing: 2) {
              Text(type.format(selected.value)).font(.headline.monospacedDigit())
              if selected.isEstimated {
                Text("geschätzt").font(.caption2)
              }
              Text(selected.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(6)
            .background(.regularMaterial, in: .rect(cornerRadius: 8))
          }
      }
    }
    .chartXScale(domain: domain.start...domain.end)
    .chartYScale(domain: .automatic(includesZero: false))
    .chartXSelection(value: $selectedDate)
    .chartAccessibilityDescription(type.title)
  }

  private func isOutOfRange(_ measurement: BodyMeasurement) -> Bool {
    referenceRange.map { !$0.contains(measurement.value) } ?? false
  }

  private func accessibilityValue(_ measurement: BodyMeasurement) -> String {
    var parts = [type.format(measurement.value)]
    if measurement.isEstimated { parts.append(String(localized: "geschätzt")) }
    if isOutOfRange(measurement) { parts.append(String(localized: "außerhalb des Referenzbereichs")) }
    return parts.joined(separator: ", ")
  }
}

extension View {
  fileprivate func chartAccessibilityDescription(_ title: String) -> some View {
    accessibilityElement(children: .contain)
      .accessibilityLabel(Text("Diagramm \(title)"))
  }
}

/// Filled circle for measured values, hollow circle for estimated ones (F-MESS-09).
/// Out-of-range values are red and larger, so the information is not conveyed by colour alone (NF-07).
struct PointSymbol: View {
  let isEstimated: Bool
  let isOutOfRange: Bool

  var body: some View {
    let color = isOutOfRange ? Color.red : Color.categoryMeasurements
    let size: CGFloat = isOutOfRange ? 11 : 8
    if isEstimated {
      Circle().strokeBorder(color, lineWidth: 2).background(Circle().fill(.background)).frame(width: size, height: size)
    } else {
      Circle().fill(color).frame(width: size, height: size)
    }
  }
}

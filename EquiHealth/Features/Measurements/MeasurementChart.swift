import Charts
import EquiCore
import SwiftUI

/// Chart of one measurement type (F-MESS-03, F-MESS-04, F-MESS-09, F-UI-03).
/// Reference band, filled points for measured and hollow points for estimated values,
/// out-of-range points highlighted, selection gesture for single values.
struct MeasurementChart: View {
  let type: MeasurementType
  /// Single values or bucket summaries in ascending time order (`ChartSeries`, NF-04).
  let points: [ChartPoint]
  let domain: DateInterval
  let referenceRange: ReferenceRange?
  @Binding var selectedDate: Date?

  private var selected: ChartPoint? {
    guard let selectedDate else { return nil }
    return points.min {
      abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
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
      ForEach(points) { point in
        if point.isSummary && point.maximum > point.minimum {
          RuleMark(
            x: .value("Zeitpunkt", point.date),
            yStart: .value("Minimum", point.minimum),
            yEnd: .value("Maximum", point.maximum)
          )
          .foregroundStyle(Color.categoryMeasurements.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
          .accessibilityHidden(true)
        }
        LineMark(
          x: .value("Zeitpunkt", point.date),
          y: .value(type.title, point.value)
        )
        .foregroundStyle(Color.categoryMeasurements)
        .interpolationMethod(.monotone)
        .accessibilityHidden(true)

        PointMark(
          x: .value("Zeitpunkt", point.date),
          y: .value(type.title, point.value)
        )
        .symbol {
          PointSymbol(isEstimated: point.containsEstimate, isOutOfRange: point.isOutOfRange(referenceRange))
        }
        .accessibilityLabel(Text(dateText(point)))
        .accessibilityValue(Text(accessibilityValue(point)))
      }
      if let selected {
        RuleMark(x: .value("Auswahl", selected.date))
          .foregroundStyle(.secondary)
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
          .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
            VStack(alignment: .leading, spacing: 2) {
              Text(type.format(selected.value)).font(.headline.monospacedDigit())
              if selected.isSummary {
                Text(
                  "Ø aus \(selected.count) Werten, \(type.format(selected.minimum)) – \(type.format(selected.maximum))"
                )
                .font(.caption2)
              } else if selected.containsEstimate {
                Text("geschätzt").font(.caption2)
              }
              Text(dateText(selected))
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

  private func dateText(_ point: ChartPoint) -> String {
    if let interval = point.interval {
      return (interval.start..<interval.end).formatted(.interval.day().month(.abbreviated).year())
    }
    return point.date.formatted(date: .abbreviated, time: .shortened)
  }

  private func accessibilityValue(_ point: ChartPoint) -> String {
    var parts = [type.format(point.value)]
    if point.isSummary {
      parts.append(String(localized: "Mittelwert aus \(point.count) Werten"))
      parts.append(String(localized: "Spanne \(type.format(point.minimum)) bis \(type.format(point.maximum))"))
    } else if point.containsEstimate {
      parts.append(String(localized: "geschätzt"))
    }
    if point.isOutOfRange(referenceRange) { parts.append(String(localized: "außerhalb des Referenzbereichs")) }
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

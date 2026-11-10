import Foundation
import Testing

@testable import EquiCore

@Suite("Diagramm-Verdichtung (NF-04, F-MESS-03)")
struct ChartSeriesTests {
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  private func samples(_ count: Int, every seconds: Double) -> [ChartSeries.Sample] {
    (0..<count).map {
      ChartSeries.Sample(
        date: start.addingTimeInterval(Double($0) * seconds), value: Double($0 % 10), isEstimated: $0 == 5)
    }
  }

  @Test("Bis zur Grenze bleiben alle Einzelwerte erhalten")
  func smallSeriesStaysRaw() {
    let input = samples(150, every: 3600)
    let points = ChartSeries.points(
      from: input, domain: DateInterval(start: start, duration: 150 * 3600), rawLimit: 200, buckets: 90)
    #expect(points.count == 150)
    #expect(points.allSatisfy { !$0.isSummary && $0.count == 1 })
    #expect(points[5].containsEstimate)
  }

  @Test("Lange Reihen werden zu höchstens 90 Abschnitten mit Mittel, Minimum und Maximum")
  func longSeriesIsBucketed() {
    let input = samples(1_800, every: 2 * 86_400)
    let domain = DateInterval(start: start, duration: 3_600 * 86_400)
    let points = ChartSeries.points(from: input, domain: domain, rawLimit: 200, buckets: 90)
    #expect(points.count <= 90)
    #expect(points.count > 80)
    #expect(points.map(\.count).reduce(0, +) == 1_800, "Kein Wert geht verloren")
    #expect(points.allSatisfy { $0.isSummary && $0.minimum <= $0.value && $0.value <= $0.maximum })
    #expect(points == points.sorted { $0.date < $1.date })
    #expect(points.first?.containsEstimate == true)
    let range = ReferenceRange(lower: 1, upper: 8)
    #expect(points.contains { $0.isOutOfRange(range) }, "Spanne zählt für „außerhalb“")
    #expect(!points[0].isOutOfRange(nil))
  }
}

import Foundation

/// One point of a measurement chart: a single value or the summary of a time bucket (NF-04).
public struct ChartPoint: Identifiable, Equatable, Sendable {
  /// Time of the value, or the middle of the bucket.
  public var date: Date
  /// The value, or the mean of the bucket.
  public var value: Double
  public var minimum: Double
  public var maximum: Double
  public var count: Int
  /// At least one value of the bucket is estimated (F-MESS-09).
  public var containsEstimate: Bool
  /// Bucket range; `nil` for a single value.
  public var interval: DateInterval?

  public var id: Date { date }
  public var isSummary: Bool { interval != nil }

  /// Whether any value lies outside `range` (F-MESS-04).
  public func isOutOfRange(_ range: ReferenceRange?) -> Bool {
    guard let range else { return false }
    return !range.contains(minimum) || !range.contains(maximum)
  }
}

/// Reduces long series for the chart, like Apple Health shows averages for long periods (NF-04).
public enum ChartSeries {
  public struct Sample: Sendable {
    public var date: Date
    public var value: Double
    public var isEstimated: Bool

    public init(date: Date, value: Double, isEstimated: Bool) {
      self.date = date
      self.value = value
      self.isEstimated = isEstimated
    }
  }

  /// Single values if there are at most `rawLimit`, otherwise one point per equally long time
  /// bucket of `domain` (`buckets` buckets: mean, minimum, maximum). Samples are expected in
  /// ascending time order.
  public static func points(
    from samples: [Sample], domain: DateInterval, rawLimit: Int = 200, buckets: Int = 90
  ) -> [ChartPoint] {
    let maxPoints = buckets
    guard samples.count > rawLimit, maxPoints > 0, domain.duration > 0 else {
      return samples.map {
        ChartPoint(
          date: $0.date, value: $0.value, minimum: $0.value, maximum: $0.value, count: 1,
          containsEstimate: $0.isEstimated, interval: nil)
      }
    }
    let width = domain.duration / Double(maxPoints)
    var buckets: [Int: [Sample]] = [:]
    for sample in samples {
      let index = min(maxPoints - 1, max(0, Int(sample.date.timeIntervalSince(domain.start) / width)))
      buckets[index, default: []].append(sample)
    }
    return buckets.keys.sorted().compactMap { index in
      guard let bucket = buckets[index], !bucket.isEmpty else { return nil }
      let start = domain.start.addingTimeInterval(Double(index) * width)
      let values = bucket.map(\.value)
      return ChartPoint(
        date: start.addingTimeInterval(width / 2), value: values.reduce(0, +) / Double(values.count),
        minimum: values.min() ?? 0, maximum: values.max() ?? 0, count: values.count,
        containsEstimate: bucket.contains(where: \.isEstimated), interval: DateInterval(start: start, duration: width))
    }
  }
}

import Foundation

/// User-defined reference range of a measurement type (F-MESS-04).
/// This is a user setting, never a medical limit supplied by the app.
public struct ReferenceRange: Codable, Equatable, Sendable {
  public var lower: Double
  public var upper: Double

  /// Creates a range; swaps the bounds if they are given in the wrong order.
  public init(lower: Double, upper: Double) {
    self.lower = min(lower, upper)
    self.upper = max(lower, upper)
  }

  public func contains(_ value: Double) -> Bool {
    value >= lower && value <= upper
  }

  /// Position of a value relative to the range.
  public func classify(_ value: Double) -> Position {
    if value < lower { return .below }
    if value > upper { return .above }
    return .within
  }

  public enum Position: Sendable {
    case below, within, above
  }
}

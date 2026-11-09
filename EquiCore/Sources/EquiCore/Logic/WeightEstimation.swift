import Foundation

/// Weight estimation without a scale (F-MESS-07).
///
/// weight (kg) ≈ chest girth² (cm) × body length (cm) ÷ 11,880
///
/// Chest girth is measured directly behind the withers (not the belly girth); body length is
/// the distance from the point of the shoulder to the point of the buttock. Less accurate for
/// foals, ponies and very heavy breeds (F-MESS-10).
public enum WeightEstimation {
  public static let divisor = 11_880.0

  /// Estimated weight in kg, or `nil` if an input is not positive.
  public static func estimatedWeight(chestGirthCM: Double, bodyLengthCM: Double) -> Double? {
    guard chestGirthCM > 0, bodyLengthCM > 0, chestGirthCM.isFinite, bodyLengthCM.isFinite else {
      return nil
    }
    return chestGirthCM * chestGirthCM * bodyLengthCM / divisor
  }
}

import Foundation

/// Resolves the "active" horse (F-PFERD-02): the stored one if still available, else the first.
public enum ActiveHorseSelection {
  /// - Parameter horses: non-archived horses in display order.
  public static func resolve(storedID: UUID?, in horses: [Horse]) -> Horse? {
    if let storedID, let match = horses.first(where: { $0.id == storedID }) {
      return match
    }
    return horses.first
  }
}

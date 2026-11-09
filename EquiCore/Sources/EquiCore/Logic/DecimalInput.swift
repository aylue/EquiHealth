import Foundation

/// Parses user-typed decimal numbers, accepting both "1,5" and "1.5".
public enum DecimalInput {
  /// A single separator ("," or ".") is always read as decimal separator, because grouped
  /// thousands do not occur in horse measurements. Text with both separators is parsed with `locale`.
  public static func parse(_ text: String, locale: Locale = .current) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let value: Double?
    if trimmed.contains(",") && trimmed.contains(".") {
      value = try? Double(trimmed, format: .number.locale(locale))
    } else {
      value = Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }
    return value.flatMap { $0.isFinite ? $0 : nil }
  }
}

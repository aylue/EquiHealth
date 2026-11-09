import Foundation

/// CSV format (F-CSV-03). Both are UTF-8 with BOM, CRLF line endings and ISO-8601 dates.
public enum CSVFormat: String, CaseIterable, Sendable {
  /// "Excel (Deutsch)": semicolon, decimal comma.
  case excelGerman
  /// "Standard": comma, decimal point.
  case standard

  public var separator: Character {
    switch self {
    case .excelGerman: ";"
    case .standard: ","
    }
  }

  public var decimalSeparator: String {
    switch self {
    case .excelGerman: ","
    case .standard: "."
    }
  }
}

/// A cell value; formatting depends on `CSVFormat`.
public enum CSVValue: Equatable, Sendable {
  case text(String)
  case number(Double)
  /// Date and time, ISO 8601 with time zone offset.
  case timestamp(Date)
  /// Calendar date only, ISO 8601 `yyyy-MM-dd`.
  case day(Date)
  case bool(Bool)
  case empty

  public static func text(_ value: String?) -> CSVValue { value.map(CSVValue.text) ?? .empty }
  public static func number(_ value: Double?) -> CSVValue { value.map(CSVValue.number) ?? .empty }
  public static func number(_ value: Int?) -> CSVValue { value.map { .number(Double($0)) } ?? .empty }
  public static func timestamp(_ value: Date?) -> CSVValue { value.map(CSVValue.timestamp) ?? .empty }
  public static func day(_ value: Date?) -> CSVValue { value.map(CSVValue.day) ?? .empty }
  public static func bool(_ value: Bool?) -> CSVValue { value.map(CSVValue.bool) ?? .empty }
}

/// One CSV file (F-CSV-01).
public struct CSVTable: Equatable, Sendable {
  /// File name including `.csv`.
  public var fileName: String
  public var header: [String]
  public var rows: [[CSVValue]]

  public init(fileName: String, header: [String], rows: [[CSVValue]]) {
    self.fileName = fileName
    self.header = header
    self.rows = rows
  }
}

/// Writes RFC-4180-conformant CSV (F-CSV-05).
public enum CSVWriter {
  static let byteOrderMark = Data([0xEF, 0xBB, 0xBF])

  /// Encloses the field in quotes if it contains the separator, a quote, CR or LF; doubles quotes.
  public static func escape(_ field: String, separator: Character) -> String {
    let needsQuoting = field.contains(separator) || field.contains("\"") || field.contains("\n") || field.contains("\r")
    guard needsQuoting else { return field }
    return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }

  public static func format(_ value: CSVValue, as format: CSVFormat, timeZone: TimeZone = .current) -> String {
    switch value {
    case .text(let text):
      return text
    case .number(let number):
      var text =
        number.rounded() == number && abs(number) < 1e15
        ? String(Int64(number))
        : String(format: "%.6f", number).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
      if text.hasSuffix(".") { text.removeLast() }
      return text.replacingOccurrences(of: ".", with: format.decimalSeparator)
    case .timestamp(let date):
      let formatter = ISO8601DateFormatter()
      formatter.timeZone = timeZone
      formatter.formatOptions = [.withInternetDateTime]
      return formatter.string(from: date)
    case .day(let date):
      let formatter = ISO8601DateFormatter()
      formatter.timeZone = timeZone
      formatter.formatOptions = [.withFullDate]
      return formatter.string(from: date)
    case .bool(let flag):
      return flag ? "ja" : "nein"
    case .empty:
      return ""
    }
  }

  /// UTF-8 with BOM, header line, CRLF line endings.
  public static func data(for table: CSVTable, format: CSVFormat, timeZone: TimeZone = .current) -> Data {
    var lines = [
      table.header.map { escape($0, separator: format.separator) }.joined(separator: String(format.separator))
    ]
    for row in table.rows {
      lines.append(
        row.map { escape(Self.format($0, as: format, timeZone: timeZone), separator: format.separator) }
          .joined(separator: String(format.separator)))
    }
    return byteOrderMark + Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
  }
}

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

  /// Formatters for one file; creating them per cell is slow (NF-04).
  struct Formatters {
    let timestamp: ISO8601DateFormatter
    let day: ISO8601DateFormatter

    init(timeZone: TimeZone) {
      timestamp = ISO8601DateFormatter()
      timestamp.timeZone = timeZone
      timestamp.formatOptions = [.withInternetDateTime]
      day = ISO8601DateFormatter()
      day.timeZone = timeZone
      day.formatOptions = [.withFullDate]
    }
  }

  public static func format(_ value: CSVValue, as format: CSVFormat, timeZone: TimeZone = .current) -> String {
    Self.format(value, as: format, formatters: Formatters(timeZone: timeZone))
  }

  static func format(_ value: CSVValue, as format: CSVFormat, formatters: Formatters) -> String {
    switch value {
    case .text(let text):
      return text
    case .number(let number):
      return numberText(number).replacingOccurrences(of: ".", with: format.decimalSeparator)
    case .timestamp(let date):
      return formatters.timestamp.string(from: date)
    case .day(let date):
      return formatters.day.string(from: date)
    case .bool(let flag):
      return flag ? "ja" : "nein"
    case .empty:
      return ""
    }
  }

  /// Integers without decimals, otherwise at most 6 decimals, always with a decimal point.
  static func numberText(_ number: Double) -> String {
    if number.rounded() == number && abs(number) < 1e15 {
      return String(Int64(number))
    }
    let rounded = (number * 1_000_000).rounded() / 1_000_000
    if rounded.rounded() == rounded && abs(rounded) < 1e15 {
      return String(Int64(rounded))
    }
    return String(rounded)
  }

  /// UTF-8 with BOM, header line, CRLF line endings.
  public static func data(for table: CSVTable, format: CSVFormat, timeZone: TimeZone = .current) -> Data {
    let formatters = Formatters(timeZone: timeZone)
    let separator = String(format.separator)
    var lines = [table.header.map { escape($0, separator: format.separator) }.joined(separator: separator)]
    lines.reserveCapacity(table.rows.count + 1)
    for row in table.rows {
      lines.append(
        row.map { escape(Self.format($0, as: format, formatters: formatters), separator: format.separator) }
          .joined(separator: separator))
    }
    return byteOrderMark + Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
  }
}

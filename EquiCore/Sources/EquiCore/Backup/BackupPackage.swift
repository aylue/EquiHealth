import Foundation
import UniformTypeIdentifiers

/// An `.equibackup` package: a directory with `backup.json` and the binary files it references
/// (F-BACKUP-01).
public struct BackupPackage: Sendable {
  public static let jsonFileName = "backup.json"
  /// Uniform type identifier, declared in the app's Info.plist (`UTExportedTypeDeclarations`).
  public static let typeIdentifier = "de.aylu.equihealth.backup"
  public static let fileExtension = "equibackup"

  public var document: BackupDocument
  /// Binary files by relative path, e.g. `attachments/<id>.jpg`.
  public var files: [String: Data]

  public init(document: BackupDocument, files: [String: Data] = [:]) {
    self.document = document
    self.files = files
  }

  /// Dates as ISO 8601 with milliseconds, e.g. `2026-11-09T10:15:30.123Z`.
  public static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(date.formatted(Self.dateStyle))
    }
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()

  /// Accepts ISO 8601 with and without fractional seconds.
  public static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let text = try container.decode(String.self)
      if let date = try? Date(text, strategy: Self.dateStyle) { return date }
      if let date = try? Date(text, strategy: .iso8601) { return date }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(text)")
    }
    return decoder
  }()

  private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

  /// Directory file wrapper for writing or exporting the package.
  public func fileWrapper() throws -> FileWrapper {
    var children: [String: FileWrapper] = [:]
    children[Self.jsonFileName] = FileWrapper(regularFileWithContents: try Self.encoder.encode(document))
    var folders: [String: [String: FileWrapper]] = [:]
    for (path, data) in files {
      let parts = path.split(separator: "/", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { continue }
      folders[parts[0], default: [:]][parts[1]] = FileWrapper(regularFileWithContents: data)
    }
    for (folder, files) in folders {
      children[folder] = FileWrapper(directoryWithFileWrappers: files)
    }
    return FileWrapper(directoryWithFileWrappers: children)
  }

  /// Reads a package; throws `BackupError.invalidPackage` if `backup.json` is missing or unreadable.
  public init(fileWrapper: FileWrapper) throws {
    guard fileWrapper.isDirectory, let children = fileWrapper.fileWrappers,
      let json = children[Self.jsonFileName]?.regularFileContents
    else { throw BackupError.invalidPackage }
    do {
      document = try Self.decoder.decode(BackupDocument.self, from: json)
    } catch {
      throw BackupError.invalidPackage
    }
    var files: [String: Data] = [:]
    for (folder, wrapper) in children where wrapper.isDirectory {
      for (name, file) in wrapper.fileWrappers ?? [:] {
        if let data = file.regularFileContents { files["\(folder)/\(name)"] = data }
      }
    }
    self.files = files
  }

  public init(url: URL) throws {
    try self.init(fileWrapper: FileWrapper(url: url, options: .immediate))
  }
}

/// Errors when reading or restoring a backup.
public enum BackupError: Error, Equatable, Sendable {
  case invalidPackage
  /// The backup was written by a newer app version.
  case unsupportedSchemaVersion(Int)
  /// A file referenced in `backup.json` is missing from the package.
  case missingFile(String)
}

/// How a backup is restored (F-BACKUP-03).
public enum BackupRestoreMode: String, Sendable {
  /// Delete all current data, then import the backup.
  case replace
  /// Keep current data; records whose UUID already exists are skipped.
  case merge
}

/// Preview shown before restoring (F-BACKUP-03).
public struct BackupPreview: Equatable, Sendable {
  public var schemaVersion: Int
  public var appVersion: String
  public var exportedAt: Date
  public var horseNames: [String]
  public var entryCount: Int
  public var fileCount: Int

  public init(package: BackupPackage) {
    let document = package.document
    schemaVersion = document.schemaVersion
    appVersion = document.appVersion
    exportedAt = document.exportedAt
    horseNames = document.horses.sorted { $0.sortIndex < $1.sortIndex }.map(\.name)
    entryCount = document.recordCount - document.horses.count
    fileCount = package.files.count
  }
}

/// Result of a restore.
public struct BackupRestoreSummary: Equatable, Sendable {
  public var inserted: Int
  public var skipped: Int
}

extension UTType {
  /// `.equibackup` package (F-BACKUP-01).
  public static let equiBackup = UTType(exportedAs: BackupPackage.typeIdentifier, conformingTo: .package)
}

import EquiCore
import SwiftUI
import UniformTypeIdentifiers

/// One CSV file for `fileExporter` (F-CSV-04).
struct CSVFileDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.commaSeparatedText]

  let name: String
  let data: Data

  init(file: ExportFile) {
    name = file.name
    data = file.data
  }

  init(configuration: ReadConfiguration) throws {
    name = configuration.file.filename ?? "Export.csv"
    data = configuration.file.regularFileContents ?? Data()
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let wrapper = FileWrapper(regularFileWithContents: data)
    wrapper.preferredFilename = name
    return wrapper
  }
}

/// An `.equibackup` package for `fileExporter` (F-BACKUP-01).
struct BackupFileDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.equiBackup]

  let package: BackupPackage

  init(package: BackupPackage) {
    self.package = package
  }

  init(configuration: ReadConfiguration) throws {
    package = try BackupPackage(fileWrapper: configuration.file)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    try package.fileWrapper()
  }
}

enum ExportFiles {
  /// Writes CSV files into a fresh temporary folder for the share sheet (F-CSV-04).
  static func temporaryURLs(for files: [ExportFile]) throws -> [URL] {
    let folder = FileManager.default.temporaryDirectory.appending(path: "EquiHealth-Export-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return try files.map { file in
      let url = folder.appending(path: file.name)
      try file.data.write(to: url, options: .atomic)
      return url
    }
  }

  /// "EquiHealth-Backup-2026-11-10"
  static func backupFileName(date: Date = .now) -> String {
    "EquiHealth-Backup-\(date.formatted(.iso8601.year().month().day()))"
  }
}

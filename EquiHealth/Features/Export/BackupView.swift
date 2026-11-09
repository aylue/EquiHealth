import EquiCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Full backup and restore with preview (F-BACKUP-01 to -05).
struct BackupView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(AppState.self) private var appState

  @State private var createdPackage: BackupPackage?
  @State private var isWorking = false
  @State private var showsExporter = false
  @State private var showsImporter = false
  @State private var importedPackage: BackupPackage?
  @State private var message: String?

  var body: some View {
    Form {
      Section {
        LabeledContent("Letztes Backup") {
          Text(
            appState.lastBackupDate.map { $0.formatted(date: .long, time: .shortened) }
              ?? String(localized: "noch keins"))
        }
        .accessibilityIdentifier("backup.last")
        Button {
          Task { await createBackup() }
        } label: {
          HStack {
            Label("Backup erstellen", systemImage: "externaldrive.badge.plus")
            if isWorking {
              Spacer()
              ProgressView()
            }
          }
        }
        .disabled(isWorking)
        .accessibilityIdentifier("backup.create")
        if let createdPackage {
          let preview = BackupPreview(package: createdPackage)
          LabeledContent("Inhalt") {
            Text("\(preview.horseNames.count) Pferde, \(preview.entryCount) Einträge, \(preview.fileCount) Dateien")
          }
          .accessibilityIdentifier("backup.summary")
          Button("In Dateien sichern", systemImage: "folder") { showsExporter = true }
            .accessibilityIdentifier("backup.save")
        }
      } header: {
        Text("Backup")
      } footer: {
        Text(
          "Ein Backup enthält alle Pferde und Einträge mit Fotos und Anhängen, aber keine Wetterdaten. Mit kostenlosem Apple-Account läuft die App nach 7 Tagen ab: Sichere regelmäßig, zum Beispiel in iCloud Drive oder auf einem Mac."
        )
      }

      Section {
        Button("Backup wiederherstellen", systemImage: "arrow.counterclockwise") { showsImporter = true }
          .accessibilityIdentifier("backup.restore")
      } footer: {
        Text(
          "Vor dem Wiederherstellen siehst du, was das Backup enthält, und wählst zwischen Zusammenführen und Ersetzen."
        )
      }

      if let message {
        Section { Text(message) }
          .accessibilityIdentifier("backup.message")
      }
    }
    .navigationTitle("Backup")
    .fileExporter(
      isPresented: $showsExporter, document: createdPackage.map(BackupFileDocument.init), contentType: .equiBackup,
      defaultFilename: ExportFiles.backupFileName()
    ) { result in
      switch result {
      case .success:
        appState.lastBackupDate = .now
        message = String(localized: "Backup gesichert.")
      case .failure:
        message = String(localized: "Das Backup konnte nicht gesichert werden.")
      }
    }
    .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.equiBackup]) { result in
      guard case .success(let url) = result else { return }
      let accessing = url.startAccessingSecurityScopedResource()
      defer { if accessing { url.stopAccessingSecurityScopedResource() } }
      do {
        importedPackage = try BackupPackage(url: url)
        message = nil
      } catch {
        message = String(localized: "Die Datei ist kein gültiges EquiHealth-Backup.")
      }
    }
    .sheet(item: $importedPackage.identified) { item in
      RestorePreviewView(package: item.package) { result in
        importedPackage = nil
        message = result
      }
    }
  }

  private func createBackup() async {
    isWorking = true
    defer { isWorking = false }
    do {
      createdPackage = try await BackupService(modelContainer: modelContext.container).makePackage(
        appVersion: Self.appVersion)
      message = nil
    } catch {
      message = String(localized: "Das Backup konnte nicht erstellt werden.")
    }
  }

  static var appVersion: String {
    let info = Bundle.main.infoDictionary
    return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
  }
}

/// Preview of a backup with the choice between merge and replace (F-BACKUP-03).
struct RestorePreviewView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let package: BackupPackage
  let onFinish: (String) -> Void

  @State private var isWorking = false
  @State private var confirmsReplace = false
  @State private var error: String?

  var body: some View {
    let preview = BackupPreview(package: package)
    NavigationStack {
      Form {
        Section("Inhalt") {
          LabeledContent("Erstellt am", value: preview.exportedAt.formatted(date: .long, time: .shortened))
          LabeledContent("App-Version", value: preview.appVersion)
          LabeledContent("Schemaversion", value: String(preview.schemaVersion))
          LabeledContent("Pferde", value: String(preview.horseNames.count))
          if !preview.horseNames.isEmpty {
            Text(preview.horseNames.formatted(.list(type: .and))).foregroundStyle(.secondary)
          }
          LabeledContent("Einträge", value: String(preview.entryCount))
          LabeledContent("Fotos und Anhänge", value: String(preview.fileCount))
        }
        Section {
          Button("Zusammenführen", systemImage: "arrow.triangle.merge") { Task { await restore(.merge) } }
            .disabled(isWorking)
            .accessibilityIdentifier("restore.merge")
          Button("Ersetzen", systemImage: "arrow.counterclockwise", role: .destructive) { confirmsReplace = true }
            .disabled(isWorking)
            .accessibilityIdentifier("restore.replace")
        } footer: {
          Text(
            "Zusammenführen ergänzt fehlende Einträge; vorhandene werden nicht doppelt angelegt. Ersetzen löscht zuerst alle Daten auf diesem Gerät."
          )
        }
        if isWorking {
          Section { ProgressView() }
        }
        if let error {
          Section { Text(error).foregroundStyle(.red) }
        }
      }
      .navigationTitle("Backup wiederherstellen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
            .disabled(isWorking)
        }
      }
      .confirmationDialog("Alle Daten ersetzen?", isPresented: $confirmsReplace, titleVisibility: .visible) {
        Button("Ersetzen", role: .destructive) { Task { await restore(.replace) } }
      } message: {
        Text("Alle Pferde und Einträge auf diesem Gerät werden durch das Backup ersetzt.")
      }
      .interactiveDismissDisabled(isWorking)
    }
  }

  private func restore(_ mode: BackupRestoreMode) async {
    isWorking = true
    defer { isWorking = false }
    do {
      let summary = try await BackupService(modelContainer: modelContext.container).restore(package, mode: mode)
      onFinish(
        String(
          localized: "Wiederhergestellt: \(summary.inserted) Einträge neu, \(summary.skipped) bereits vorhanden."))
    } catch BackupError.unsupportedSchemaVersion {
      error = String(
        localized: "Dieses Backup stammt aus einer neueren App-Version. Bitte zuerst die App aktualisieren.")
    } catch BackupError.missingFile {
      error = String(localized: "Das Backup ist unvollständig. Es wurde nichts verändert.")
    } catch {
      self.error = String(localized: "Wiederherstellen fehlgeschlagen. Es wurde nichts verändert.")
    }
  }
}

/// Wraps an optional package so it can drive `sheet(item:)`.
struct IdentifiedPackage: Identifiable {
  let id = UUID()
  let package: BackupPackage
}

extension Binding where Value == BackupPackage? {
  var identified: Binding<IdentifiedPackage?> {
    Binding<IdentifiedPackage?>(
      get: { wrappedValue.map { IdentifiedPackage(package: $0) } },
      set: { if $0 == nil { wrappedValue = nil } })
  }
}

import EquiCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// CSV export with horse and period filter and two formats (F-CSV-01 to -04).
struct CSVExportView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Horse.sortIndex) private var horses: [Horse]

  @State private var selectedHorseIDs: Set<UUID>?
  @State private var areas = Set(CSVArea.allCases)
  @State private var limitsPeriod = false
  @State private var periodStart = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
  @State private var periodEnd = Date.now
  @State private var format = CSVFormat.excelGerman
  @State private var files: [ExportFile] = []
  @State private var shareURLs: [URL] = []
  @State private var isWorking = false
  @State private var showsExporter = false
  @State private var message: String?

  private var horseIDs: Set<UUID> { selectedHorseIDs ?? Set(horses.map(\.id)) }

  var body: some View {
    Form {
      Section("Pferde") {
        ForEach(horses) { horse in
          Toggle(
            horse.name,
            isOn: Binding(
              get: { horseIDs.contains(horse.id) },
              set: { isOn in
                var ids = horseIDs
                if isOn { ids.insert(horse.id) } else { ids.remove(horse.id) }
                selectedHorseIDs = ids
                invalidate()
              }))
        }
      }

      Section {
        Toggle("Zeitraum eingrenzen", isOn: $limitsPeriod.animation())
        if limitsPeriod {
          DatePicker("Von", selection: $periodStart, displayedComponents: .date)
          DatePicker("Bis", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
        }
      } header: {
        Text("Zeitraum")
      } footer: {
        Text("Pferde und Erinnerungen werden immer vollständig exportiert.")
      }

      Section("Bereiche") {
        ForEach(CSVArea.allCases, id: \.self) { area in
          Toggle(
            area.title,
            isOn: Binding(
              get: { areas.contains(area) },
              set: { isOn in
                if isOn { areas.insert(area) } else { areas.remove(area) }
                invalidate()
              }))
        }
      }

      Section {
        Picker("Format", selection: $format) {
          Text("Excel (Deutsch)").tag(CSVFormat.excelGerman)
          Text("Standard").tag(CSVFormat.standard)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("export.format")
      } header: {
        Text("Format")
      } footer: {
        Text(
          format == .excelGerman
            ? "Semikolon und Dezimalkomma, öffnet sich in Excel mit deutscher Einstellung direkt richtig. UTF-8, Datum im ISO-8601-Format."
            : "Komma und Dezimalpunkt, zum Beispiel für Numbers oder andere Programme. UTF-8, Datum im ISO-8601-Format."
        )
      }

      Section {
        Button {
          Task { await createFiles() }
        } label: {
          HStack {
            Label("Dateien erstellen", systemImage: "doc.badge.gearshape")
            if isWorking {
              Spacer()
              ProgressView()
            }
          }
        }
        .disabled(isWorking || horseIDs.isEmpty || areas.isEmpty)
        .accessibilityIdentifier("export.create")
      }

      if !files.isEmpty {
        Section {
          ForEach(files) { file in
            LabeledContent(file.name) {
              Text(file.rowCount == 1 ? String(localized: "1 Zeile") : String(localized: "\(file.rowCount) Zeilen"))
            }
            .accessibilityIdentifier("export.file")
          }
          Button("In Dateien sichern", systemImage: "folder") { showsExporter = true }
            .accessibilityIdentifier("export.save")
          ShareLink(items: shareURLs) {
            Label("Teilen", systemImage: "square.and.arrow.up")
          }
        } header: {
          Text("Erstellt")
        }
      }

      if let message {
        Section { Text(message).foregroundStyle(.secondary) }
      }
    }
    .navigationTitle("CSV-Export")
    .onChange(of: format) { invalidate() }
    .onChange(of: limitsPeriod) { invalidate() }
    .onChange(of: periodStart) { invalidate() }
    .onChange(of: periodEnd) { invalidate() }
    .fileExporter(
      isPresented: $showsExporter, documents: files.map(CSVFileDocument.init), contentType: .commaSeparatedText
    ) { result in
      switch result {
      case .success: message = String(localized: "Gesichert.")
      case .failure: message = String(localized: "Die Dateien konnten nicht gesichert werden.")
      }
    }
  }

  private func invalidate() {
    files = []
    shareURLs = []
    message = nil
  }

  private func createFiles() async {
    isWorking = true
    defer { isWorking = false }
    let calendar = Calendar.current
    let interval: DateInterval? =
      limitsPeriod
      ? DateInterval(
        start: calendar.startOfDay(for: periodStart),
        end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: periodEnd)) ?? periodEnd)
      : nil
    do {
      let exporter = CSVExporter(modelContainer: modelContext.container)
      files = try await exporter.makeFiles(horseIDs: horseIDs, areas: areas, interval: interval, format: format)
      shareURLs = try ExportFiles.temporaryURLs(for: files)
      message = nil
    } catch {
      files = []
      message = String(localized: "Der Export ist fehlgeschlagen.")
    }
  }
}

extension CSVArea {
  var title: String {
    switch self {
    case .horses: String(localized: "Pferde")
    case .measurements: String(localized: "Messwerte")
    case .feeding: String(localized: "Fütterung (Plan und Abweichungen)")
    case .symptoms: String(localized: "Symptome")
    case .conditions: String(localized: "Krankheiten")
    case .treatments: String(localized: "Behandlungen")
    case .medications: String(localized: "Medikamente")
    case .reminders: String(localized: "Erinnerungen")
    case .training: String(localized: "Trainingseinheiten")
    }
  }
}

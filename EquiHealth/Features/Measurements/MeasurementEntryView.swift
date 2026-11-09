import EquiCore
import SwiftData
import SwiftUI

/// Quick entry and editing of a measurement (F-MESS-01, F-MESS-02): value, time preset to now, save.
struct MeasurementEntryView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  let horse: Horse
  /// Measurement being edited; `nil` creates a new one.
  let existing: BodyMeasurement?

  @State private var type: MeasurementType
  @State private var valueText: String
  @State private var timestamp: Date
  @State private var method: MeasurementMethod
  @State private var note: String
  @State private var showsEstimation = false
  @FocusState private var valueFocused: Bool

  init(horse: Horse, type: MeasurementType, existing: BodyMeasurement? = nil) {
    self.horse = horse
    self.existing = existing
    let type = existing?.type ?? type
    _type = State(initialValue: type)
    _valueText = State(initialValue: existing.map { type.inputText($0.value) } ?? "")
    _timestamp = State(initialValue: existing?.timestamp ?? .now)
    _method = State(initialValue: existing?.method ?? type.defaultMethod)
    _note = State(initialValue: existing?.note ?? "")
  }

  private var value: Double? {
    DecimalInput.parse(valueText).flatMap { $0 > 0 ? $0 : nil }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          if existing == nil {
            Picker("Messwert", selection: $type) {
              ForEach(MeasurementType.allCases) { type in
                Label(type.title, systemImage: type.systemImage).tag(type)
              }
            }
          }
          HStack {
            TextField("Wert", text: $valueText)
              .keyboardType(.decimalPad)
              .focused($valueFocused)
              .font(.title2.monospacedDigit())
              .accessibilityLabel(Text(type.title))
              .accessibilityIdentifier("measurement.value")
            Text(type.inputUnitLabel)
              .foregroundStyle(.secondary)
          }
          DatePicker("Zeitpunkt", selection: $timestamp)
          if type.availableMethods.count > 1 {
            Picker("Methode", selection: $method) {
              ForEach(type.availableMethods, id: \.self) { method in
                Text(method.title).tag(method)
              }
            }
          }
        } header: {
          Text(horse.name)
        }

        if type == .weight && existing == nil {
          Section {
            Button("Gewicht ohne Waage schätzen", systemImage: "function") { showsEstimation = true }
          } footer: {
            Text("Aus Brustumfang und Körperlänge.")
          }
        }

        Section("Notiz") {
          TextField("Notiz", text: $note, axis: .vertical)
        }
      }
      .navigationTitle(existing == nil ? "Messwert erfassen" : "Messwert bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(value == nil)
            .accessibilityIdentifier("save")
        }
      }
      .onChange(of: type) { _, newType in
        if !newType.availableMethods.contains(method) { method = newType.defaultMethod }
      }
      .navigationDestination(isPresented: $showsEstimation) {
        WeightEstimationView(horse: horse, isRoot: false) { dismiss() }
      }
      .onAppear { valueFocused = existing == nil }
    }
  }

  private func save() {
    guard let value else { return }
    let target = existing ?? BodyMeasurement(horse: horse, type: type, value: value)
    if existing == nil { modelContext.insert(target) }
    target.type = type
    target.value = value
    target.timestamp = timestamp
    target.method = method
    target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    target.touch()
    try? modelContext.save()
    dismiss()
  }
}

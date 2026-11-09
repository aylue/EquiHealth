import EquiCore
import SwiftUI

/// Edit the user's own reference range of a measurement type (F-MESS-04).
struct ReferenceRangeEditor: View {
  @Environment(AppState.self) private var appState
  @Environment(\.dismiss) private var dismiss

  let horse: Horse
  let type: MeasurementType

  @State private var isEnabled = false
  @State private var lowerText = ""
  @State private var upperText = ""

  private var range: ReferenceRange? {
    guard let lower = DecimalInput.parse(lowerText), let upper = DecimalInput.parse(upperText) else { return nil }
    return ReferenceRange(lower: lower, upper: upper)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle("Referenzbereich anzeigen", isOn: $isEnabled.animation())
          if isEnabled {
            field("Untergrenze", text: $lowerText, identifier: "reference.lower")
            field("Obergrenze", text: $upperText, identifier: "reference.upper")
          }
        } footer: {
          Text(
            "Der Bereich ist deine eigene Einstellung, zum Beispiel nach Absprache mit deinem Tierarzt. Die App gibt keine Grenzwerte vor."
          )
        }
      }
      .navigationTitle("Referenzbereich")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") {
            appState.setReferenceRange(isEnabled ? range : nil, for: type, horseID: horse.id)
            dismiss()
          }
          .disabled(isEnabled && range == nil)
          .accessibilityIdentifier("save")
        }
      }
      .onAppear {
        guard let existing = appState.referenceRange(for: type, horseID: horse.id) else { return }
        isEnabled = true
        lowerText = type.inputText(existing.lower)
        upperText = type.inputText(existing.upper)
      }
    }
  }

  private func field(_ title: LocalizedStringKey, text: Binding<String>, identifier: String) -> some View {
    LabeledContent(title) {
      HStack {
        TextField("0", text: text)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .accessibilityLabel(Text(title))
          .accessibilityIdentifier(identifier)
        Text(type.inputUnitLabel).foregroundStyle(.secondary)
      }
    }
  }
}

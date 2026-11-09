import EquiCore
import SwiftData
import SwiftUI

/// Weight estimation from chest girth and body length (F-MESS-07, F-MESS-08, F-MESS-10).
struct WeightEstimationView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  let horse: Horse
  /// `true` when shown as the root of a sheet (adds a cancel button).
  let isRoot: Bool
  var onSaved: (() -> Void)?

  @State private var girthText = ""
  @State private var lengthText = ""
  @State private var timestamp = Date.now
  @State private var storesMeasures = true

  private var girth: Double? { DecimalInput.parse(girthText) }
  private var length: Double? { DecimalInput.parse(lengthText) }
  private var estimate: Double? {
    guard let girth, let length else { return nil }
    return WeightEstimation.estimatedWeight(chestGirthCM: girth, bodyLengthCM: length)
  }

  var body: some View {
    Form {
      Section {
        GirthLengthSketch()
          .frame(height: 170)
          .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        Label {
          Text("**Brustumfang:** Gurtumfang direkt hinter dem Widerrist – nicht der Bauchumfang.")
        } icon: {
          Image(systemName: "lasso").foregroundStyle(.tint)
        }
        Label {
          Text("**Körperlänge:** vom Buggelenk bis zum Sitzbeinhöcker.")
        } icon: {
          Image(systemName: "arrow.left.and.right").foregroundStyle(.secondary)
        }
      }
      .font(.subheadline)

      Section("Maße") {
        measureField("Brustumfang", text: $girthText, identifier: "estimation.girth")
        measureField("Körperlänge", text: $lengthText, identifier: "estimation.length")
        DatePicker("Zeitpunkt", selection: $timestamp)
        Toggle("Maße ebenfalls speichern", isOn: $storesMeasures)
      }

      Section {
        LabeledContent("Geschätztes Gewicht") {
          Text(estimate.map { MeasurementType.weight.format($0) } ?? "–")
            .font(.title2.bold().monospacedDigit())
            .foregroundStyle(estimate == nil ? .secondary : .primary)
        }
        .accessibilityIdentifier("estimation.result")
      } footer: {
        Text(
          "Gewicht ≈ Brustumfang² × Körperlänge ÷ 11.880. Bei Fohlen, Ponys und sehr schweren Rassen ist die Formel ungenauer."
        )
      }
    }
    .navigationTitle("Gewicht schätzen")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if isRoot {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Sichern") { save() }
          .disabled(estimate == nil)
          .accessibilityIdentifier("save")
      }
    }
  }

  private func measureField(_ title: LocalizedStringKey, text: Binding<String>, identifier: String) -> some View {
    LabeledContent(title) {
      HStack {
        TextField("0", text: text)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .accessibilityLabel(Text(title))
          .accessibilityIdentifier(identifier)
        Text("cm").foregroundStyle(.secondary)
      }
    }
  }

  private func save() {
    guard let estimate, let girth, let length else { return }
    modelContext.insert(
      BodyMeasurement(horse: horse, type: .weight, value: estimate, timestamp: timestamp, method: .estimationFormula))
    if storesMeasures {
      modelContext.insert(
        BodyMeasurement(horse: horse, type: .chestGirth, value: girth, timestamp: timestamp, method: .measuringTape))
      modelContext.insert(
        BodyMeasurement(horse: horse, type: .bodyLength, value: length, timestamp: timestamp, method: .measuringTape))
    }
    try? modelContext.save()
    if let onSaved {
      onSaved()
    } else {
      dismiss()
    }
  }
}

/// Simple side-view sketch showing where chest girth and body length are measured (F-MESS-08).
struct GirthLengthSketch: View {
  var body: some View {
    Canvas { context, size in
      // Drawing in a 200 × 120 design space, scaled to fit.
      let scale = min(size.width / 200, size.height / 120)
      context.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height - 120 * scale) / 2)
      context.scaleBy(x: scale, y: scale)

      let outline = GraphicsContext.Shading.style(.secondary)
      let fill = GraphicsContext.Shading.style(.secondary.opacity(0.2))

      var horse = Path()
      horse.addEllipse(in: CGRect(x: 52, y: 42, width: 110, height: 44))  // body
      horse.move(to: CGPoint(x: 70, y: 50))  // neck
      horse.addLine(to: CGPoint(x: 42, y: 18))
      horse.addLine(to: CGPoint(x: 54, y: 12))
      horse.addLine(to: CGPoint(x: 84, y: 46))
      horse.addRoundedRect(in: CGRect(x: 22, y: 8, width: 30, height: 15), cornerSize: CGSize(width: 7, height: 7))
      for x in [66.0, 80, 136, 150] {
        horse.addRoundedRect(in: CGRect(x: x, y: 78, width: 7, height: 36), cornerSize: CGSize(width: 3, height: 3))
      }
      horse.move(to: CGPoint(x: 160, y: 52))  // tail
      horse.addQuadCurve(to: CGPoint(x: 172, y: 96), control: CGPoint(x: 178, y: 62))
      context.fill(horse, with: fill)
      context.stroke(horse, with: outline, lineWidth: 1.5)

      // Chest girth: loop directly behind the withers.
      let girth = Path(ellipseIn: CGRect(x: 80, y: 36, width: 14, height: 56))
      context.stroke(girth, with: .style(.tint), style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))

      // Body length: point of shoulder to point of buttock.
      var length = Path()
      length.move(to: CGPoint(x: 56, y: 60))
      length.addLine(to: CGPoint(x: 162, y: 60))
      for (tip, direction) in [(CGPoint(x: 56, y: 60), 1.0), (CGPoint(x: 162, y: 60), -1.0)] {
        length.move(to: CGPoint(x: tip.x + 6 * direction, y: tip.y - 4))
        length.addLine(to: tip)
        length.addLine(to: CGPoint(x: tip.x + 6 * direction, y: tip.y + 4))
      }
      context.stroke(length, with: .style(.primary), lineWidth: 2)
    }
    .accessibilityElement()
    .accessibilityLabel(
      Text(
        "Skizze: Der Brustumfang wird direkt hinter dem Widerrist rund um den Körper gemessen, die Körperlänge vom Buggelenk bis zum Sitzbeinhöcker."
      ))
  }
}

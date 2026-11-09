import EquiCore
import SwiftUI

/// Type-specific symptom details (SPEC section 3) for cough, muscle stiffness, colic and eye inflammation.
struct SymptomDetailsEditor: View {
  let category: SymptomCategory
  @Binding var details: SymptomDetails

  var body: some View {
    switch category {
    case .cough: coughSection
    case .muscleStiffness: stiffnessSection
    case .colic: colicSection
    case .eyeInflammation: eyeSection
    default: EmptyView()
    }
  }

  private var cough: Binding<SymptomDetails.Cough> {
    Binding(get: { details.cough ?? .init() }, set: { details.cough = $0 })
  }

  private var stiffness: Binding<SymptomDetails.MuscleStiffness> {
    Binding(get: { details.muscleStiffness ?? .init() }, set: { details.muscleStiffness = $0 })
  }

  private var colic: Binding<SymptomDetails.Colic> {
    Binding(get: { details.colic ?? .init() }, set: { details.colic = $0 })
  }

  private var eye: Binding<SymptomDetails.EyeInflammation> {
    Binding(get: { details.eyeInflammation ?? .init() }, set: { details.eyeInflammation = $0 })
  }

  private var coughSection: some View {
    Section("Details Husten") {
      Picker("Art", selection: cough.kind) {
        Text("Keine Angabe").tag(SymptomDetails.Cough.Kind?.none)
        Text("trocken").tag(SymptomDetails.Cough.Kind?.some(.dry))
        Text("feucht").tag(SymptomDetails.Cough.Kind?.some(.wet))
      }
      Toggle("Nasenausfluss", isOn: cough.hasNasalDischarge.orFalse)
      if cough.wrappedValue.hasNasalDischarge == true {
        TextField(
          "Farbe des Ausflusses",
          text: Binding(
            get: { cough.wrappedValue.nasalDischargeColor ?? "" },
            set: { cough.wrappedValue.nasalDischargeColor = $0.nilIfBlank }))
      }
      Toggle("in Ruhe", isOn: cough.situations.contains(.rest))
      Toggle("bei der Arbeit", isOn: cough.situations.contains(.work))
      Toggle("beim Füttern", isOn: cough.situations.contains(.feeding))
    }
  }

  private var stiffnessSection: some View {
    Section("Details Spannigkeit") {
      TextField(
        "Betroffene Region",
        text: Binding(
          get: { stiffness.wrappedValue.affectedRegion ?? "" },
          set: { stiffness.wrappedValue.affectedRegion = $0.nilIfBlank }))
      Toggle("Nach der Arbeit", isOn: stiffness.afterWork.orFalse)
      Toggle("Muskulatur hart", isOn: stiffness.musclesHard.orFalse)
    }
  }

  private var colicSection: some View {
    Section("Details Kolik") {
      LabeledContent("Dauer") {
        HStack {
          TextField(
            "0",
            text: Binding(
              get: { colic.wrappedValue.duration.map { String(Int($0 / 60)) } ?? "" },
              set: { colic.wrappedValue.duration = DecimalInput.parse($0).map { $0 * 60 } }
            )
          )
          .keyboardType(.numberPad)
          .multilineTextAlignment(.trailing)
          .accessibilityLabel(Text("Dauer in Minuten"))
          Text("min").foregroundStyle(.secondary)
        }
      }
      Toggle("Scharren", isOn: colic.signs.contains(.pawing))
        .accessibilityIdentifier("colic.pawing")
      Toggle("Wälzen", isOn: colic.signs.contains(.rolling))
      Toggle("Schwitzen", isOn: colic.signs.contains(.sweating))
      Toggle("Kein Kotabsatz", isOn: colic.signs.contains(.noManure))
      Toggle("Tierarzt gerufen", isOn: colic.veterinarianCalled.orFalse)
        .accessibilityIdentifier("colic.vetCalled")
    }
  }

  private var eyeSection: some View {
    Section("Details Augenentzündung") {
      Picker("Auge", selection: eye.eye) {
        Text("Keine Angabe").tag(SymptomDetails.EyeInflammation.Eye?.none)
        Text("links").tag(SymptomDetails.EyeInflammation.Eye?.some(.left))
        Text("rechts").tag(SymptomDetails.EyeInflammation.Eye?.some(.right))
        Text("beide").tag(SymptomDetails.EyeInflammation.Eye?.some(.both))
      }
      Toggle("Tränenfluss", isOn: eye.tearing.orFalse)
      Toggle("Schwellung", isOn: eye.swelling.orFalse)
      Toggle("Lichtempfindlich", isOn: eye.photosensitivity.orFalse)
    }
  }
}

/// Keeps only the details belonging to `category`.
extension SymptomDetails {
  func restricted(to category: SymptomCategory) -> SymptomDetails {
    switch category {
    case .cough: SymptomDetails(cough: cough)
    case .muscleStiffness: SymptomDetails(muscleStiffness: muscleStiffness)
    case .colic: SymptomDetails(colic: colic)
    case .eyeInflammation: SymptomDetails(eyeInflammation: eyeInflammation)
    default: SymptomDetails()
    }
  }

  /// Human-readable lines for the detail view.
  var summaryLines: [String] {
    var lines: [String] = []
    if let cough {
      if let kind = cough.kind {
        lines.append(kind == .dry ? String(localized: "trocken") : String(localized: "feucht"))
      }
      if cough.hasNasalDischarge == true {
        lines.append(
          cough.nasalDischargeColor.map { String(localized: "Nasenausfluss (\($0))") }
            ?? String(localized: "Nasenausfluss"))
      }
      let situations = (cough.situations ?? []).map { situation in
        switch situation {
        case .rest: String(localized: "in Ruhe")
        case .work: String(localized: "bei der Arbeit")
        case .feeding: String(localized: "beim Füttern")
        }
      }
      if !situations.isEmpty { lines.append(situations.formatted(.list(type: .and))) }
    }
    if let muscleStiffness {
      if let region = muscleStiffness.affectedRegion { lines.append(String(localized: "Region: \(region)")) }
      if muscleStiffness.afterWork == true { lines.append(String(localized: "nach der Arbeit")) }
      if muscleStiffness.musclesHard == true { lines.append(String(localized: "Muskulatur hart")) }
    }
    if let colic {
      if let duration = colic.duration {
        lines.append(
          String(localized: "Dauer: \(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes])))"))
      }
      let signs = (colic.signs ?? []).map { sign in
        switch sign {
        case .pawing: String(localized: "Scharren")
        case .rolling: String(localized: "Wälzen")
        case .sweating: String(localized: "Schwitzen")
        case .noManure: String(localized: "kein Kotabsatz")
        }
      }
      if !signs.isEmpty { lines.append(signs.formatted(.list(type: .and))) }
      if colic.veterinarianCalled == true { lines.append(String(localized: "Tierarzt gerufen")) }
    }
    if let eyeInflammation {
      if let eye = eyeInflammation.eye {
        let name =
          switch eye {
          case .left: String(localized: "links")
          case .right: String(localized: "rechts")
          case .both: String(localized: "beide Augen")
          }
        lines.append(String(localized: "Auge: \(name)"))
      }
      if eyeInflammation.tearing == true { lines.append(String(localized: "Tränenfluss")) }
      if eyeInflammation.swelling == true { lines.append(String(localized: "Schwellung")) }
      if eyeInflammation.photosensitivity == true { lines.append(String(localized: "lichtempfindlich")) }
    }
    return lines
  }
}

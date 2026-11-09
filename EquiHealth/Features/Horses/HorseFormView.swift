import EquiCore
import PhotosUI
import SwiftData
import SwiftUI

/// Create or edit a horse (F-PFERD-01).
struct HorseFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var appState

  /// `nil` creates a new horse.
  let horse: Horse?

  @State private var name = ""
  @State private var callName = ""
  @State private var hasBirthDate = false
  @State private var birthDate = Date.now
  @State private var breed = ""
  @State private var sex: HorseSex?
  @State private var color = ""
  @State private var markings = ""
  @State private var ueln = ""
  @State private var microchipNumber = ""
  @State private var isFoodProducingAnimal: Bool?
  @State private var photoData: Data?
  @State private var photoItem: PhotosPickerItem?
  @State private var notes = ""

  init(horse: Horse?) {
    self.horse = horse
    guard let horse else { return }
    _name = State(initialValue: horse.name)
    _callName = State(initialValue: horse.callName ?? "")
    _hasBirthDate = State(initialValue: horse.birthDate != nil)
    _birthDate = State(initialValue: horse.birthDate ?? .now)
    _breed = State(initialValue: horse.breed ?? "")
    _sex = State(initialValue: horse.sex)
    _color = State(initialValue: horse.color ?? "")
    _markings = State(initialValue: horse.markings ?? "")
    _ueln = State(initialValue: horse.ueln ?? "")
    _microchipNumber = State(initialValue: horse.microchipNumber ?? "")
    _isFoodProducingAnimal = State(initialValue: horse.isFoodProducingAnimal)
    _photoData = State(initialValue: horse.photoData)
    _notes = State(initialValue: horse.notes)
  }

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Spacer()
            VStack(spacing: 12) {
              HorseAvatar(photoData: photoData, size: 96)
              PhotosPicker(
                photoData == nil ? "Foto auswählen" : "Foto ändern", selection: $photoItem, matching: .images)
              if photoData != nil {
                Button("Foto entfernen", role: .destructive) { photoData = nil }
              }
            }
            Spacer()
          }
        }
        .listRowBackground(Color.clear)

        Section {
          TextField("Name", text: $name)
            .textContentType(.name)
            .accessibilityIdentifier("horse.name")
          TextField("Rufname", text: $callName)
        }

        Section("Stammdaten") {
          Toggle("Geburtsdatum bekannt", isOn: $hasBirthDate.animation())
          if hasBirthDate {
            DatePicker("Geburtsdatum", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
          }
          TextField("Rasse", text: $breed)
          Picker("Geschlecht", selection: $sex) {
            Text("Keine Angabe").tag(HorseSex?.none)
            ForEach(HorseSex.allCases, id: \.self) { sex in
              Text(sex.title).tag(Optional(sex))
            }
          }
          TextField("Farbe", text: $color)
          TextField("Abzeichen", text: $markings, axis: .vertical)
        }

        Section {
          TextField("UELN", text: $ueln)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
          TextField("Chipnummer", text: $microchipNumber)
            .keyboardType(.numberPad)
          Picker("Schlachttier", selection: $isFoodProducingAnimal) {
            Text("Keine Angabe").tag(Bool?.none)
            Text("Ja").tag(Bool?.some(true))
            Text("Nein").tag(Bool?.some(false))
          }
        } header: {
          Text("Equidenpass")
        } footer: {
          Text("Status laut Equidenpass. Bei Schlachttieren hebt die App Lebensmittel-Wartezeiten hervor.")
        }

        Section("Notizen") {
          TextField("Notizen", text: $notes, axis: .vertical)
            .lineLimit(3...)
        }
      }
      .navigationTitle(horse == nil ? "Neues Pferd" : "Pferd bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(trimmedName.isEmpty)
            .accessibilityIdentifier("save")
        }
      }
      .onChange(of: photoItem) { _, item in
        Task { await loadPhoto(item) }
      }
    }
  }

  private func loadPhoto(_ item: PhotosPickerItem?) async {
    guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
    photoData = ImageDownscaler.jpegData(from: data)
  }

  private func save() {
    let target: Horse
    if let horse {
      target = horse
    } else {
      let existing = (try? modelContext.fetch(FetchDescriptor<Horse>())) ?? []
      target = Horse(name: trimmedName, sortIndex: (existing.map(\.sortIndex).max() ?? -1) + 1)
      modelContext.insert(target)
    }
    target.name = trimmedName
    target.callName = callName.nilIfBlank
    target.birthDate = hasBirthDate ? birthDate : nil
    target.breed = breed.nilIfBlank
    target.sex = sex
    target.color = color.nilIfBlank
    target.markings = markings.nilIfBlank
    target.ueln = ueln.nilIfBlank
    target.microchipNumber = microchipNumber.nilIfBlank
    target.isFoodProducingAnimal = isFoodProducingAnimal
    target.photoData = photoData
    target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    target.touch()
    try? modelContext.save()
    if horse == nil {
      // A newly created horse becomes the active one.
      appState.activeHorseID = target.id
    }
    dismiss()
  }
}

extension String {
  /// `nil` for empty or whitespace-only strings, otherwise the trimmed string.
  var nilIfBlank: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

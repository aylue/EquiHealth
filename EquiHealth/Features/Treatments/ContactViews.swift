import EquiCore
import SwiftData
import SwiftUI

/// Reusable contacts (F-BEH-05). Shared master data (F-TEIL-01).
struct ContactsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Contact.name) private var contacts: [Contact]
  @State private var showsNewContact = false

  var body: some View {
    List {
      if contacts.isEmpty {
        ContentUnavailableView {
          Label("Keine Kontakte", systemImage: "person.crop.rectangle.stack")
        } description: {
          Text("Lege Tierarzt, Hufschmied und Therapeuten einmal an und verwende sie in Behandlungen wieder.")
        } actions: {
          Button("Kontakt anlegen") { showsNewContact = true }
            .buttonStyle(.borderedProminent)
        }
      }
      ForEach(ContactRole.allCases, id: \.self) { role in
        let group = contacts.filter { $0.role == role }
        if !group.isEmpty {
          Section(role.title) {
            ForEach(group) { contact in
              NavigationLink {
                ContactDetailView(contact: contact)
              } label: {
                VStack(alignment: .leading) {
                  Text(contact.name)
                  if let practice = contact.practice {
                    Text(practice).font(.caption).foregroundStyle(.secondary)
                  }
                }
              }
            }
            .onDelete { offsets in
              for index in offsets { modelContext.delete(group[index]) }
              try? modelContext.save()
            }
          }
        }
      }
    }
    .navigationTitle("Kontakte")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Kontakt hinzufügen", systemImage: "plus") { showsNewContact = true }
      }
    }
    .sheet(isPresented: $showsNewContact) {
      ContactFormView(contact: nil)
    }
  }
}

/// Contact detail with call and e-mail actions (F-BEH-05).
struct ContactDetailView: View {
  @Bindable var contact: Contact
  @State private var showsEditor = false

  var body: some View {
    List {
      Section {
        ContactSummary(contact: contact)
      }
      if let address = contact.address {
        Section("Adresse") { Text(address) }
      }
      let treatments = (contact.treatments ?? []).sorted { $0.date > $1.date }
      if !treatments.isEmpty {
        Section("Behandlungen") {
          ForEach(treatments) { treatment in
            NavigationLink {
              TreatmentDetailView(treatment: treatment)
            } label: {
              VStack(alignment: .leading) {
                TreatmentRow(treatment: treatment)
                if let horse = treatment.horse {
                  Text(horse.name).font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle(contact.name)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Bearbeiten") { showsEditor = true }
      }
    }
    .sheet(isPresented: $showsEditor) {
      ContactFormView(contact: contact)
    }
  }
}

/// Name, role, practice and tap-to-call / tap-to-mail links.
struct ContactSummary: View {
  let contact: Contact

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(contact.name).font(.headline)
      Text([contact.role.title, contact.practice].compactMap { $0 }.joined(separator: " · "))
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    if let phone = contact.phone, let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
      Link(destination: url) {
        Label(phone, systemImage: "phone")
      }
      .accessibilityLabel(Text("\(contact.name) anrufen"))
    }
    if let email = contact.email, let url = URL(string: "mailto:\(email)") {
      Link(destination: url) {
        Label(email, systemImage: "envelope")
      }
      .accessibilityLabel(Text("E-Mail an \(contact.name)"))
    }
  }
}

/// Create or edit a contact.
struct ContactFormView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let contact: Contact?
  var onCreate: ((Contact) -> Void)?

  @State private var name: String
  @State private var role: ContactRole
  @State private var practice: String
  @State private var phone: String
  @State private var email: String
  @State private var address: String

  init(contact: Contact?, role: ContactRole = .veterinarian, onCreate: ((Contact) -> Void)? = nil) {
    self.contact = contact
    self.onCreate = onCreate
    _name = State(initialValue: contact?.name ?? "")
    _role = State(initialValue: contact?.role ?? role)
    _practice = State(initialValue: contact?.practice ?? "")
    _phone = State(initialValue: contact?.phone ?? "")
    _email = State(initialValue: contact?.email ?? "")
    _address = State(initialValue: contact?.address ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
            .textContentType(.name)
            .accessibilityIdentifier("contact.name")
          Picker("Rolle", selection: $role) {
            ForEach(ContactRole.allCases, id: \.self) { role in
              Text(role.title).tag(role)
            }
          }
          TextField("Praxis", text: $practice)
            .textContentType(.organizationName)
        }
        Section {
          TextField("Telefon", text: $phone)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
          TextField("E-Mail", text: $email)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          TextField("Adresse", text: $address, axis: .vertical)
            .textContentType(.fullStreetAddress)
        }
      }
      .navigationTitle(contact == nil ? "Neuer Kontakt" : "Kontakt bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") { save() }
            .disabled(name.nilIfBlank == nil)
            .accessibilityIdentifier("contact.save")
        }
      }
    }
  }

  private func save() {
    guard let trimmed = name.nilIfBlank else { return }
    let target = contact ?? Contact(name: trimmed, role: role)
    if contact == nil { modelContext.insert(target) }
    target.name = trimmed
    target.role = role
    target.practice = practice.nilIfBlank
    target.phone = phone.nilIfBlank
    target.email = email.nilIfBlank
    target.address = address.nilIfBlank
    target.touch()
    try? modelContext.save()
    if contact == nil { onCreate?(target) }
    dismiss()
  }
}

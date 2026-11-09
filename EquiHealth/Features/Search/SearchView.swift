import SwiftUI

/// "Suche" tab: full-text search across notes, symptoms, treatments and medications.
struct SearchView: View {
  @State private var query = ""

  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label("Suche", systemImage: "magnifyingglass")
      } description: {
        Text("Durchsuche Notizen, Symptome, Behandlungen und Medikamente.")
      }
      .navigationTitle("Suche")
      .searchable(text: $query)
    }
  }
}

#Preview {
  SearchView()
}

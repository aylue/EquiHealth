import SwiftUI

/// "Durchsuchen" tab with health categories. Filled from phase 1 on.
struct BrowseView: View {
  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label("Noch keine Kategorien", systemImage: "square.grid.2x2")
      } description: {
        Text("Hier erscheinen Messwerte, Fütterung, Gesundheit und Behandlungen.")
      }
      .navigationTitle("Durchsuchen")
    }
  }
}

#Preview {
  BrowseView()
}

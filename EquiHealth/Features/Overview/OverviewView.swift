import SwiftUI

/// "Übersicht" tab, like "Summary" in Apple Health. Filled in phase 1.
struct OverviewView: View {
  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label("Noch keine Pferde", systemImage: "list.bullet.clipboard")
      } description: {
        Text("Lege ein Pferd an, um Messwerte, Fütterung und Gesundheit zu erfassen.")
      }
      .navigationTitle("Übersicht")
    }
  }
}

#Preview {
  OverviewView()
}

import SwiftUI

/// "Termine" tab: reminders of all horses (F-ERIN-04). Filled in phase 4.
struct AppointmentsView: View {
  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label("Keine Termine", systemImage: "calendar")
      } description: {
        Text("Fällige Impfungen, Hufschmied- und Zahntermine erscheinen hier.")
      }
      .navigationTitle("Termine")
      .appToolbar()
    }
  }
}

#Preview {
  AppointmentsView()
}

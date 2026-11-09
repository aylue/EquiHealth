import EquiCore
import SwiftData
import SwiftUI

/// First-start onboarding in three steps (F-UI-06): create a horse, optionally set a stable,
/// optionally allow notifications. Includes the liability notice (NF-11).
struct OnboardingView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Environment(AppState.self) private var appState
  @Environment(ReminderNotificationService.self) private var notifications

  private enum Step { case horse, stable, notifications }

  @State private var step = Step.horse
  @State private var horseName = ""
  @State private var stableName = ""
  @State private var stableLocality = ""

  var body: some View {
    NavigationStack {
      Form {
        switch step {
        case .horse: horseStep
        case .stable: stableStep
        case .notifications: notificationsStep
        }
      }
      .navigationTitle(title)
      .toolbar {
        switch step {
        case .horse:
          ToolbarItem(placement: .cancellationAction) {
            Button("Später") { finish(createHorse: false) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Weiter") { step = .stable }
              .disabled(horseName.nilIfBlank == nil)
              .accessibilityIdentifier("onboarding.next")
          }
        case .stable:
          ToolbarItem(placement: .cancellationAction) {
            Button("Überspringen") {
              stableName = ""
              step = .notifications
            }
            .accessibilityIdentifier("onboarding.skip")
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Weiter") { step = .notifications }
              .disabled(stableName.nilIfBlank == nil)
          }
        case .notifications:
          ToolbarItem(placement: .confirmationAction) {
            Button("Fertig") { finish(createHorse: true, createStable: stableName.nilIfBlank != nil) }
              .accessibilityIdentifier("onboarding.finish")
          }
        }
      }
    }
  }

  @ViewBuilder private var horseStep: some View {
    Section {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: "figure.equestrian.sports")
          .font(.largeTitle)
          .foregroundStyle(.tint)
          .accessibilityHidden(true)
        Text(
          "EquiHealth ist das Gesundheitstagebuch für deine Pferde: Messwerte, Fütterung, Symptome und Termine an einem Ort."
        )
      }
      .padding(.vertical, 4)
    }
    Section {
      TextField("Name des Pferdes", text: $horseName)
        .accessibilityIdentifier("onboarding.horseName")
    } header: {
      Text("Schritt 1 von 3: Pferd anlegen")
    } footer: {
      Text("Weitere Angaben kannst du später im Pferdeprofil ergänzen.")
    }
    Section {
      DisclaimerText()
    }
  }

  @ViewBuilder private var stableSection: some View {
    TextField("Name des Stalls", text: $stableName)
    TextField("Ort", text: $stableLocality)
  }

  @ViewBuilder private var stableStep: some View {
    Section {
      stableSection
    } header: {
      Text("Schritt 2 von 3: Stall (optional)")
    } footer: {
      Text("Über den Stall ordnet die App später Wetterdaten zu. Du kannst ihn auch später festlegen.")
    }
  }

  private var title: LocalizedStringKey {
    switch step {
    case .horse: "Willkommen"
    case .stable: "Stall"
    case .notifications: "Erinnerungen"
    }
  }

  @ViewBuilder private var notificationsStep: some View {
    Section {
      Label {
        Text("EquiHealth erinnert dich an Impfungen, Hufschmied, Zahnkontrolle und Wurmkur.")
      } icon: {
        Image(systemName: "bell.badge").foregroundStyle(.tint)
      }
      switch notifications.authorizationStatus {
      case .notDetermined:
        Button("Mitteilungen erlauben") {
          Task { await notifications.requestAuthorization() }
        }
        .accessibilityIdentifier("onboarding.allowNotifications")
      case .denied:
        Text("Mitteilungen sind abgelehnt. Du kannst sie später in den iOS-Einstellungen erlauben.")
          .foregroundStyle(.secondary)
      default:
        Label("Mitteilungen sind erlaubt", systemImage: "checkmark.circle")
      }
    } header: {
      Text("Schritt 3 von 3: Mitteilungen (optional)")
    } footer: {
      Text("Du kannst das jederzeit in den Einstellungen ändern.")
    }
  }

  private func finish(createHorse: Bool, createStable: Bool = false) {
    if createHorse, let name = horseName.nilIfBlank {
      let horse = Horse(name: name)
      modelContext.insert(horse)
      if createStable, let stableName = stableName.nilIfBlank {
        let stable = Stable(name: stableName)
        stable.locality = stableLocality.nilIfBlank
        modelContext.insert(stable)
        horse.move(to: stable, on: Calendar.current.startOfDay(for: .now), in: modelContext)
      }
      try? modelContext.save()
      appState.activeHorseID = horse.id
    }
    appState.hasCompletedOnboarding = true
    dismiss()
  }
}

/// Liability notice (NF-11).
struct DisclaimerText: View {
  var body: some View {
    Label {
      Text(
        "Die App ersetzt keine tierärztliche Beratung. Referenzbereiche und Wartezeiten sind deine eigenen Eingaben.")
    } icon: {
      Image(systemName: "stethoscope")
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
  }
}

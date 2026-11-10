import Combine
import EquiCore
import SwiftData
import SwiftUI

/// Main tabs (SPEC section 5).
enum AppTab: String, Hashable, CaseIterable {
  case overview
  case browse
  case appointments
  case search
}

/// Main navigation: tab bar on iPhone, sidebar on iPad (`.sidebarAdaptable`).
struct RootView: View {
  @Environment(AppState.self) private var appState
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Environment(ReminderNotificationService.self) private var notifications
  @SceneStorage("selectedTab") private var selectedTab: AppTab = .overview
  @Query private var allHorses: [Horse]

  var body: some View {
    @Bindable var appState = appState
    TabView(selection: $selectedTab) {
      Tab("Übersicht", systemImage: "heart.text.square", value: AppTab.overview) {
        OverviewView()
      }
      Tab("Durchsuchen", systemImage: "square.grid.2x2", value: AppTab.browse) {
        BrowseView()
      }
      Tab("Termine", systemImage: "calendar", value: AppTab.appointments) {
        AppointmentsView()
      }
      Tab(value: AppTab.search, role: .search) {
        SearchView()
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    // F-TRAIN-05: equihealth://horse/<uuid> makes the horse active and shows its overview.
    .onOpenURL { url in
      guard case .horse(let id) = DeepLink(url: url), allHorses.contains(where: { $0.id == id }) else { return }
      appState.activeHorseID = id
      appState.sheet = nil
      selectedTab = .overview
    }
    .sheet(item: $appState.sheet) { sheet in
      AppSheetContent(sheet: sheet)
        .interactiveDismissDisabled(sheet == .onboarding)
    }
    // Saves of background contexts (weather cache, backup restore) arrive off the main thread.
    .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: DispatchQueue.main)) { _ in
      // F-ERIN-05: re-plan after every change.
      notifications.scheduleReschedule()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background {
        Task { await notifications.submitBackgroundRefresh() }
      }
    }
    .onChange(of: appState.showsRemindersOnThisDevice) { notifications.scheduleReschedule() }
    .onChange(of: appState.notifiesCompetitionWithdrawalEnd) { notifications.scheduleReschedule() }
    .task {
      await notifications.refreshAuthorizationStatus()
      await notifications.reschedule()
      appState.migrateLegacyReferenceRanges(of: allHorses, in: modelContext)
      // F-UI-06: onboarding on first start.
      if !appState.hasCompletedOnboarding && allHorses.isEmpty {
        appState.sheet = .onboarding
      }
    }
  }
}

/// Content of the app-wide sheets.
private struct AppSheetContent: View {
  let sheet: AppSheet

  var body: some View {
    switch sheet {
    case .newMeasurement(let type):
      ActiveHorseReader { horse in
        if let horse { MeasurementEntryView(horse: horse, type: type) }
      }
    case .estimateWeight:
      ActiveHorseReader { horse in
        if let horse {
          NavigationStack { WeightEstimationView(horse: horse, isRoot: true) }
        }
      }
    case .newSymptom:
      ActiveHorseReader { horse in
        if let horse { SymptomFormView(horse: horse) }
      }
    case .newCondition:
      ActiveHorseReader { horse in
        if let horse { ConditionFormView(horse: horse) }
      }
    case .newTreatment:
      ActiveHorseReader { horse in
        if let horse { TreatmentFormView(horse: horse) }
      }
    case .newFeedingLog:
      ActiveHorseReader { horse in
        if let horse { FeedingLogFormView(horse: horse, log: nil) }
      }
    case .newReminder:
      ReminderRuleFormView(rule: nil)
    case .editReminder(let id):
      ReminderRuleLoader(id: id) { ReminderRuleFormView(rule: $0) }
    case .treatmentForRule(let id):
      ReminderRuleLoader(id: id) { rule in
        if let horse = rule.horse {
          TreatmentFormView(
            horse: horse, kind: rule.matchingTreatmentKind ?? .other,
            vaccinationTarget: rule.matchingVaccinationTarget)
        }
      }
    case .newHorse:
      HorseFormView(horse: nil)
    case .horseProfile:
      ActiveHorseReader { horse in
        if let horse {
          NavigationStack { HorseProfileView(horse: horse).closeButton() }
        }
      }
    case .horseManagement:
      NavigationStack { HorseManagementView().closeButton() }
    case .stables:
      NavigationStack { StablesView().closeButton() }
    case .contacts:
      NavigationStack { ContactsView().closeButton() }
    case .feeds:
      NavigationStack { FeedsView().closeButton() }
    case .settings:
      NavigationStack { SettingsView().closeButton() }
    case .onboarding:
      OnboardingView()
    }
  }
}

extension View {
  /// Adds a "Fertig" button that dismisses the presenting sheet.
  func closeButton() -> some View {
    modifier(CloseButton())
  }
}

private struct CloseButton: ViewModifier {
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content.toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Fertig") { dismiss() }
          .accessibilityIdentifier("closeSheet")
      }
    }
  }
}

#Preview {
  let container = try! EquiModelContainer.make(inMemory: true)
  let appState = AppState(defaults: UserDefaults(suiteName: "preview")!)
  RootView()
    .environment(appState)
    .environment(ReminderNotificationService(container: container, appState: appState))
    .environment(WeatherService(container: container, provider: BrightSkyProvider()))
    .environment(CloudSyncMonitor())
    .modelContainer(container)
}

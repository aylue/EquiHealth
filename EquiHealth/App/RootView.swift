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
    .sheet(item: $appState.sheet) { sheet in
      AppSheetContent(sheet: sheet)
        .interactiveDismissDisabled(sheet == .onboarding)
    }
    .task {
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
  RootView()
    .environment(AppState(defaults: UserDefaults(suiteName: "preview")!))
    .modelContainer(try! EquiModelContainer.make(inMemory: true))
}

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
  @SceneStorage("selectedTab") private var selectedTab: AppTab = .overview

  var body: some View {
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
  }
}

#Preview {
  RootView()
}

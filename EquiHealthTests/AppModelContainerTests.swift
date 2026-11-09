import EquiCore
import SwiftData
import Testing

@testable import EquiHealth

@Suite("App-Gerüst (Phase 0)")
@MainActor
struct AppScaffoldTests {
  @Test("F-ARCH-05: App nutzt einen lokalen Store, alle Feature-Flags aus")
  func appRunsWithoutDeveloperAccount() throws {
    #expect(!FeatureFlags.cloudSyncEnabled)
    #expect(!FeatureFlags.sharedTrainingContainerEnabled)
    #expect(!FeatureFlags.sharingEnabled)
    #expect(!FeatureFlags.widgetsEnabled)

    let container = try EquiModelContainer.make(inMemory: true)
    let context = ModelContext(container)
    context.insert(Horse(name: "Luna"))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<Horse>()) == 1)
  }

  @Test("Hauptnavigation hat die vier Tabs aus SPEC Abschnitt 5")
  func mainTabs() {
    #expect(AppTab.allCases == [.overview, .browse, .appointments, .search])
  }
}

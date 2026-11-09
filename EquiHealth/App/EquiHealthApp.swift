import EquiCore
import SwiftData
import SwiftUI

@main
struct EquiHealthApp: App {
  private let modelContainer: ModelContainer
  @State private var appState: AppState

  init() {
    let isUITesting = ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting)
    do {
      modelContainer = try EquiModelContainer.make(inMemory: isUITesting)
    } catch {
      // ANNAHME: Ohne Datenbank ist die App nicht nutzbar; ein kontrollierter Absturz mit Meldung
      // ist vorerst akzeptabel. Eine Fehleransicht folgt mit Backup/Import (Phase 6). Q-010.
      fatalError("Could not create model container: \(error)")
    }
    let defaults: UserDefaults
    if isUITesting, let testDefaults = UserDefaults(suiteName: "EquiHealthUITesting") {
      testDefaults.removePersistentDomain(forName: "EquiHealthUITesting")
      defaults = testDefaults
    } else {
      defaults = .standard
    }
    _appState = State(initialValue: AppState(defaults: defaults))
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appState)
    }
    .modelContainer(modelContainer)
  }
}

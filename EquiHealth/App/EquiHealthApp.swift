import EquiCore
import SwiftData
import SwiftUI

@main
struct EquiHealthApp: App {
  private let modelContainer: ModelContainer

  init() {
    let isUITesting = ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting)
    do {
      modelContainer = try EquiModelContainer.make(inMemory: isUITesting)
    } catch {
      // ANNAHME: Ohne Datenbank ist die App nicht nutzbar; ein kontrollierter Absturz mit Meldung
      // ist in Phase 0 akzeptabel. Eine Fehleransicht folgt mit Backup/Import (Phase 6).
      fatalError("Could not create model container: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      RootView()
    }
    .modelContainer(modelContainer)
  }
}

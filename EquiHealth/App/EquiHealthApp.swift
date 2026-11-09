import EquiCore
import SwiftData
import SwiftUI
import UserNotifications

@main
struct EquiHealthApp: App {
  private let modelContainer: ModelContainer
  @State private var appState: AppState
  @State private var notificationService: ReminderNotificationService
  @State private var weatherService: WeatherService
  private let notificationRouter: NotificationRouter

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
    let appState = AppState(defaults: defaults)
    let service = ReminderNotificationService(container: modelContainer, appState: appState)
    _appState = State(initialValue: appState)
    _notificationService = State(initialValue: service)
    _weatherService = State(
      initialValue: WeatherService(container: modelContainer, provider: Self.weatherProvider(isUITesting: isUITesting)))
    notificationRouter = NotificationRouter(appState: appState, service: service)
    UNUserNotificationCenter.current().delegate = notificationRouter
    service.registerCategories()
  }

  /// Bright Sky in normal use; a deterministic stub in UI tests, so they never hit the network.
  private static func weatherProvider(isUITesting: Bool) -> any WeatherProvider {
    #if DEBUG
      if isUITesting {
        return StubWeatherProvider(fails: ProcessInfo.processInfo.arguments.contains("-weatherOffline"))
      }
    #endif
    return BrightSkyProvider()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(appState)
        .environment(notificationService)
        .environment(weatherService)
    }
    .modelContainer(modelContainer)
    .backgroundTask(.appRefresh(NotificationIdentifiers.refreshTask)) {
      // F-ERIN-05: keep the next 64 notifications scheduled even if the app is not opened.
      await notificationService.reschedule()
      await notificationService.submitBackgroundRefresh()
    }
  }
}

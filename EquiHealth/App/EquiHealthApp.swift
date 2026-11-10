import EquiCore
import SwiftData
import SwiftUI
import UserNotifications

/// Everything the app needs once the database is open.
@MainActor
final class AppServices {
  let modelContainer: ModelContainer
  let appState: AppState
  let notificationService: ReminderNotificationService
  let weatherService: WeatherService
  let syncMonitor = CloudSyncMonitor()
  private let notificationRouter: NotificationRouter

  init(modelContainer: ModelContainer, defaults: UserDefaults, weatherProvider: any WeatherProvider) {
    self.modelContainer = modelContainer
    appState = AppState(defaults: defaults)
    notificationService = ReminderNotificationService(container: modelContainer, appState: appState)
    weatherService = WeatherService(container: modelContainer, provider: weatherProvider)
    notificationRouter = NotificationRouter(appState: appState, service: notificationService)
    UNUserNotificationCenter.current().delegate = notificationRouter
    notificationService.registerCategories()
  }
}

@main
struct EquiHealthApp: App {
  /// `nil` if the database could not be opened; the error is then shown instead of crashing (Q-010).
  private let services: AppServices?
  private let startupError: String?

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let isUITesting = arguments.contains(LaunchArgument.uiTesting)
    let defaults: UserDefaults
    if isUITesting, let testDefaults = UserDefaults(suiteName: "EquiHealthUITesting") {
      testDefaults.removePersistentDomain(forName: "EquiHealthUITesting")
      defaults = testDefaults
    } else {
      defaults = .standard
    }
    do {
      #if DEBUG
        if arguments.contains(LaunchArgument.simulateStoreFailure) {
          throw CocoaError(.fileReadCorruptFile)
        }
      #endif
      let container = try EquiModelContainer.make(inMemory: isUITesting)
      services = AppServices(
        modelContainer: container, defaults: defaults, weatherProvider: Self.weatherProvider(isUITesting: isUITesting))
      startupError = nil
    } catch {
      services = nil
      startupError = String(describing: error)
    }
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
      if let services {
        RootView()
          .environment(services.appState)
          .environment(services.notificationService)
          .environment(services.weatherService)
          .environment(services.syncMonitor)
          .task { await services.syncMonitor.start() }
          .modelContainer(services.modelContainer)
      } else {
        DatabaseErrorView(details: startupError ?? "")
      }
    }
    .backgroundTask(.appRefresh(NotificationIdentifiers.refreshTask)) {
      // F-ERIN-05: keep the next 64 notifications scheduled even if the app is not opened.
      guard let service = services?.notificationService else { return }
      await service.reschedule()
      await service.submitBackgroundRefresh()
    }
  }
}

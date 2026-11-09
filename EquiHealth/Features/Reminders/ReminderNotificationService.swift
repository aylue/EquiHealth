import BackgroundTasks
import EquiCore
import Foundation
import Observation
import SwiftData
import UserNotifications

/// Identifiers shared by scheduling and the notification router.
nonisolated enum NotificationIdentifiers {
  static let reminderCategory = "equihealth.reminder"
  static let withdrawalCategory = "equihealth.withdrawal"
  static let doneAction = "equihealth.done"
  static let snoozeAction = "equihealth.snooze"
  static let refreshTask = "de.aylu.EquiHealth.reminderRefresh"
  static let ruleIDKey = "ruleID"
}

/// Schedules local notifications for reminders (F-ERIN-05) and optional withdrawal ends (F-BEH-11).
///
/// iOS keeps at most 64 pending notifications per app, so only the next ones are planned and the plan
/// is rebuilt at launch, after every data change, when going to the background and in a
/// `BGAppRefreshTask`.
@Observable
final class ReminderNotificationService {
  @ObservationIgnored private let container: ModelContainer
  @ObservationIgnored private let appState: AppState
  @ObservationIgnored private var pendingReschedule: Task<Void, Never>?

  /// Last known authorization status, for the settings screen.
  private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

  init(container: ModelContainer, appState: AppState) {
    self.container = container
    self.appState = appState
  }

  /// Registers the notification actions "Erledigt" and "In 1 Woche erinnern" (F-ERIN-06).
  func registerCategories() {
    let done = UNNotificationAction(
      identifier: NotificationIdentifiers.doneAction, title: String(localized: "Erledigt"),
      options: [.foreground])
    let snooze = UNNotificationAction(
      identifier: NotificationIdentifiers.snoozeAction, title: String(localized: "In 1 Woche erinnern"),
      options: [])
    let reminder = UNNotificationCategory(
      identifier: NotificationIdentifiers.reminderCategory, actions: [done, snooze], intentIdentifiers: [])
    let withdrawal = UNNotificationCategory(
      identifier: NotificationIdentifiers.withdrawalCategory, actions: [], intentIdentifiers: [])
    UNUserNotificationCenter.current().setNotificationCategories([reminder, withdrawal])
  }

  func refreshAuthorizationStatus() async {
    authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }

  /// Asks for permission (onboarding step 3, settings). Returns whether notifications are allowed.
  @discardableResult
  func requestAuthorization() async -> Bool {
    let granted =
      (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]))
      ?? false
    await refreshAuthorizationStatus()
    await reschedule()
    return granted
  }

  /// Rebuilds the plan shortly after the last call; used after data changes.
  func scheduleReschedule() {
    pendingReschedule?.cancel()
    pendingReschedule = Task {
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      await reschedule()
    }
  }

  /// Removes all pending EquiHealth notifications and schedules the next ones (F-ERIN-05).
  func reschedule(now: Date = .now) async {
    let center = UNUserNotificationCenter.current()
    let pending = await center.pendingNotificationRequests()
      .map(\.identifier)
      .filter { $0.hasPrefix(ReminderPlanner.identifierPrefix) }
    center.removePendingNotificationRequests(withIdentifiers: pending)
    guard appState.showsRemindersOnThisDevice else { return }

    let context = ModelContext(container)
    let rules = (try? context.fetch(FetchDescriptor<ReminderRule>())) ?? []
    let medications =
      appState.notifiesCompetitionWithdrawalEnd
      ? (try? context.fetch(FetchDescriptor<Medication>())) ?? [] : []
    let plan = ReminderPlanner.plan(rules: rules, medications: medications, now: now)

    let rulesByID = Dictionary(rules.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let medicationsByID = Dictionary(medications.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    for item in plan {
      let content = makeContent(for: item, rule: rulesByID[item.sourceID], medication: medicationsByID[item.sourceID])
      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: item.fireDate)
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      try? await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
    }
  }

  private func makeContent(
    for item: PlannedNotification, rule: ReminderRule?, medication: Medication?
  ) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.sound = .default
    let due = item.referenceDate.formatted(date: .long, time: .omitted)
    switch item.kind {
    case .leadTime, .due, .snoozed:
      let horseName = rule?.horse?.name ?? ""
      content.title = "\(horseName): \(rule?.title ?? "")"
      content.body =
        switch item.kind {
        case .leadTime: String(localized: "Fällig am \(due)")
        case .due: String(localized: "Heute fällig")
        default: String(localized: "Fällig seit \(due)")
        }
      content.categoryIdentifier = NotificationIdentifiers.reminderCategory
      content.userInfo = [NotificationIdentifiers.ruleIDKey: item.sourceID.uuidString]
      content.threadIdentifier = item.horseID?.uuidString ?? "reminders"
    case .competitionWithdrawalEnded:
      let horseName = medication?.treatment?.horse?.name ?? ""
      content.title = String(localized: "\(horseName): Turnier-Karenzzeit beendet")
      content.body = String(localized: "\(medication?.productName ?? ""): Karenzzeit lief bis \(due).")
      content.categoryIdentifier = NotificationIdentifiers.withdrawalCategory
    }
    return content
  }

  /// "In 1 Woche erinnern" (F-ERIN-06).
  func snooze(ruleID: UUID, now: Date = .now) async {
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<ReminderRule>(predicate: #Predicate { $0.id == ruleID })
    guard let rule = try? context.fetch(descriptor).first,
      let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)
    else { return }
    rule.snoozedUntil = rule.reminderTime(on: nextWeek) ?? nextWeek
    rule.touch()
    try? context.save()
    await reschedule(now: now)
  }

  /// Submits the next background refresh (F-ERIN-05).
  func submitBackgroundRefresh() async {
    let request = BGAppRefreshTaskRequest(identifier: NotificationIdentifiers.refreshTask)
    request.earliestBeginDate = Date.now.addingTimeInterval(6 * 60 * 60)
    try? await BGTaskScheduler.shared.submitTaskRequest(request)
  }

  #if DEBUG
    /// UI-test helper: fires a reminder notification of the first active rule after `seconds`.
    func scheduleTestNotification(after seconds: TimeInterval = 5) async {
      let context = ModelContext(container)
      guard let rule = try? context.fetch(FetchDescriptor<ReminderRule>()).first(where: \.isActive) else { return }
      let item = PlannedNotification(
        identifier: "\(ReminderPlanner.identifierPrefix)test.\(UUID().uuidString)", fireDate: .now, kind: .due,
        sourceID: rule.id, horseID: rule.horse?.id, referenceDate: rule.nextDueDate() ?? .now)
      let content = makeContent(for: item, rule: rule, medication: nil)
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
      try? await UNUserNotificationCenter.current().add(
        UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
    }
  #endif
}

/// Handles taps on notifications and their actions (F-ERIN-06).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
  private let appState: AppState
  private let service: ReminderNotificationService

  init(appState: AppState, service: ReminderNotificationService) {
    self.appState = appState
    self.service = service
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }

  /// UIKit requires the completion handler on the main thread; the `async` variant of this method
  /// resumes on a background thread and crashes, so the handler variant is used.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let action = response.actionIdentifier
    let ruleID = (response.notification.request.content.userInfo[NotificationIdentifiers.ruleIDKey] as? String)
      .flatMap(UUID.init(uuidString:))
    nonisolated(unsafe) let completion = completionHandler
    Task { @MainActor in
      await self.handle(action: action, ruleID: ruleID)
      completion()
    }
  }

  /// "Erledigt" and a tap open the prefilled treatment entry; "In 1 Woche erinnern" postpones.
  func handle(action: String, ruleID: UUID?) async {
    guard let ruleID else { return }
    switch action {
    case NotificationIdentifiers.snoozeAction:
      await service.snooze(ruleID: ruleID)
    case NotificationIdentifiers.doneAction, UNNotificationDefaultActionIdentifier:
      appState.sheet = .treatmentForRule(ruleID)
    default:
      break
    }
  }
}

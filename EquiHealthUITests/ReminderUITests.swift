import XCTest

/// Phase 4 acceptance: the rule "Influenza alle 6 Monate, 14 Tage Vorlauf" yields the right due date
/// after recording a vaccination; the notification appears and its action "Erledigt" opens the entry
/// (F-ERIN-01 to -06, F-UI-06).
final class ReminderUITests: EquiUITestCase {
  func testInfluenzaRuleDueDateAndDoneAction() throws {
    launch()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    // Onboarding with notification permission (step 3).
    let name = app.textFields["onboarding.horseName"]
    XCTAssertTrue(name.waitForExistence(timeout: 30))
    enter("Luna", into: name)
    app.buttons["onboarding.next"].tap()
    app.buttons["onboarding.skip"].tap()
    let allow = app.buttons["onboarding.allowNotifications"]
    if allow.waitForExistence(timeout: 5) {
      allow.tap()
      let systemAllow = springboard.buttons["Erlauben"]
      if systemAllow.waitForExistence(timeout: 10) { systemAllow.tap() }
    }
    XCTAssertTrue(text(containing: "Mitteilungen sind erlaubt").waitForExistence(timeout: 10))
    app.buttons["onboarding.finish"].tap()

    // Rule from template (F-ERIN-03).
    app.buttons["Termine"].firstMatch.tap()
    let create = app.buttons["reminders.create"]
    XCTAssertTrue(create.waitForExistence(timeout: 5))
    create.tap()
    let template = app.buttons["reminder.template.vaccinationInfluenza"]
    XCTAssertTrue(template.waitForExistence(timeout: 5))
    template.tap()
    XCTAssertEqual(app.textFields["reminder.interval"].value as? String, "6")
    let leadTime = app.descendants(matching: .any)["reminder.leadTime"].firstMatch
    scrollTo(leadTime)
    let leadDescription = leadTime.label + " " + ((leadTime.value as? String) ?? "")
    XCTAssertTrue(leadDescription.contains("14"), "14 Tage Vorlauf aus der Vorlage, gefunden: \(leadDescription)")
    app.buttons["reminder.save"].tap()
    XCTAssertTrue(text(containing: "noch keine passende Behandlung").waitForExistence(timeout: 5))

    // Record the vaccination.
    openAddMenu("Behandlung")
    choose("Impfung", in: app.buttons["treatment.kind"])
    let addMedication = app.buttons["treatment.addMedication"]
    scrollTo(addMedication)
    addMedication.tap()
    enter("Equilis Prequenza", into: app.textFields["medication.product"])
    turnOn(app.switches["Influenza"])
    app.buttons["medication.save"].tap()
    app.buttons["save"].tap()

    // Due date = vaccination day + 6 months.
    let calendar = Calendar.current
    let due = calendar.date(byAdding: .month, value: 6, to: calendar.startOfDay(for: .now))!
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateStyle = .long
    XCTAssertTrue(
      text(containing: formatter.string(from: due)).waitForExistence(timeout: 5),
      "Fälligkeit am \(formatter.string(from: due))")
    attachScreenshot("Termine mit Influenza-Erinnerung")

    // A notification for the rule appears; "Erledigt" opens the treatment entry (F-ERIN-06).
    tapMenuItem("Einstellungen", in: app.buttons["profileMenu"])
    let test = app.buttons["settings.testNotification"]
    scrollTo(test)
    test.tap()
    app.buttons["closeSheet"].tap()

    let banner = springboard.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS 'Impfung Influenza'")).firstMatch
    XCTAssertTrue(banner.waitForExistence(timeout: 20), "Mitteilung erscheint")
    banner.press(forDuration: 1.5)
    let done = springboard.buttons["Erledigt"]
    XCTAssertTrue(done.waitForExistence(timeout: 10), "Aktion „Erledigt“ in der Mitteilung")
    XCTAssertTrue(springboard.buttons["In 1 Woche erinnern"].exists)
    done.tap()
    _ = app.wait(for: .runningForeground, timeout: 10)
    attachScreenshot("Nach Erledigt")

    XCTAssertTrue(
      app.staticTexts["Behandlung erfassen"].waitForExistence(timeout: 10),
      "Eingabe öffnet sich; sichtbar: \(app.staticTexts.allElementsBoundByIndex.prefix(12).map(\.label))")
    XCTAssertTrue(text(containing: "Impfung").exists, "Art ist vorbelegt")
    XCTAssertTrue(text(containing: "Impfstoff (Influenza)").exists, "Impfstoff gegen Influenza ist vorbereitet")
    attachScreenshot("Erledigt öffnet vorbefüllte Eingabe")
    XCTAssertTrue(app.buttons["save"].isEnabled, "Mit einem Tipp speicherbar")
    app.buttons["save"].tap()
    XCTAssertTrue(app.buttons["save"].waitForNonExistence(timeout: 5))
  }
}

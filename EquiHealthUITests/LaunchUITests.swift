import XCTest

/// UI tests of the core flows (NF-10).
@MainActor
final class LaunchUITests: XCTestCase {
  private var app: XCUIApplication!

  /// Starts the app with an empty in-memory store and German locale.
  /// `XCUIApplication` is created here (on the main actor), not in the test case initializer.
  private func launch() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments += ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    app.launch()
  }

  /// Phase 0: the app starts with the tab structure; onboarding appears on first start (F-UI-06).
  func testLaunchShowsOnboardingAndTabs() throws {
    launch()
    XCTAssertTrue(app.textFields["onboarding.horseName"].waitForExistence(timeout: 20))
    app.buttons["Später"].tap()
    for title in ["Übersicht", "Durchsuchen", "Termine"] {
      XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 10), "Tab \(title) fehlt")
    }
    XCTAssertTrue(app.staticTexts["Noch keine Pferde"].exists)
  }

  /// Phase 1 acceptance: create two horses, switch, enter weight and temperature for each,
  /// chart with time ranges and reference band (F-PFERD-01, F-PFERD-02, F-MESS-01..04).
  func testTwoHorsesWithWeightAndTemperature() throws {
    launch()
    // Horse 1 via onboarding (NF-10 "Pferd anlegen").
    let onboardingName = app.textFields["onboarding.horseName"]
    XCTAssertTrue(onboardingName.waitForExistence(timeout: 20))
    onboardingName.tap()
    onboardingName.typeText("Luna")
    app.buttons["onboarding.next"].tap()
    app.buttons["onboarding.skip"].tap()
    XCTAssertTrue(horseSwitcher(named: "Luna").waitForExistence(timeout: 10))

    // NF-10 "Messwert eintragen".
    addMeasurement("Gewicht", value: "540")
    addMeasurement("Körpertemperatur", value: "37,6")

    // Horse 2 via horse management.
    app.buttons["profileMenu"].tap()
    app.buttons["Pferdeverwaltung"].tap()
    app.buttons["addHorse"].tap()
    let horseName = app.textFields["horse.name"]
    XCTAssertTrue(horseName.waitForExistence(timeout: 5))
    horseName.tap()
    horseName.typeText("Max")
    app.buttons["save"].tap()
    app.buttons["closeSheet"].tap()
    XCTAssertTrue(horseSwitcher(named: "Max").waitForExistence(timeout: 5), "Neues Pferd wird aktiv")

    addMeasurement("Gewicht", value: "610")
    addMeasurement("Körpertemperatur", value: "38,9")
    XCTAssertTrue(text(containing: "610").waitForExistence(timeout: 5))

    // Switch back (F-PFERD-02).
    app.buttons["horseSwitcher"].tap()
    app.buttons["Luna"].firstMatch.tap()
    XCTAssertTrue(horseSwitcher(named: "Luna").waitForExistence(timeout: 5))
    XCTAssertTrue(text(containing: "540").waitForExistence(timeout: 5))
    XCTAssertTrue(text(containing: "37,6").exists)
    XCTAssertFalse(text(containing: "610").exists, "Werte des anderen Pferdes dürfen nicht erscheinen")

    // Detail view with chart, time ranges and reference band (F-MESS-03, F-MESS-04).
    app.buttons["pinned.weight"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["measurementChart"].waitForExistence(timeout: 5))
    for range in ["Tag", "Woche", "Sechs Monate", "Jahr", "Alle", "Monat"] {
      app.segmentedControls["chartRange"].buttons[range].tap()
    }
    app.buttons["Referenzbereich festlegen"].tap()
    let toggle = app.switches["Referenzbereich anzeigen"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5))
    toggle.switches.firstMatch.tap()
    let lower = app.textFields["reference.lower"]
    XCTAssertTrue(lower.waitForExistence(timeout: 5))
    lower.tap()
    lower.typeText("500")
    let upper = app.textFields["reference.upper"]
    upper.tap()
    upper.typeText("560")
    app.buttons["save"].tap()
    XCTAssertTrue(text(containing: "Dein Bereich").waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Referenzbereich bearbeiten"].exists)

    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Gewicht-Detail mit Referenzband"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  // MARK: Helpers

  private func horseSwitcher(named name: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "identifier == 'horseSwitcher' AND label CONTAINS %@", name))
      .firstMatch
  }

  private func text(containing fragment: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
  }

  private func addMeasurement(_ type: String, value: String) {
    app.buttons["addMenu"].tap()
    app.buttons["Messwert"].tap()
    app.buttons[type].tap()
    let field = app.textFields["measurement.value"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText(value)
    app.buttons["save"].tap()
    XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Sheet für \(type) schließt nicht")
  }
}

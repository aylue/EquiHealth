import XCTest

/// UI tests of the core flows (NF-10).
final class LaunchUITests: EquiUITestCase {
  /// Phase 0: the app starts with the tab structure; onboarding appears on first start (F-UI-06).
  /// Phase 7: Settings show iCloud sync as not yet available.
  func testLaunchShowsOnboardingAndTabs() throws {
    launch()
    XCTAssertTrue(app.textFields["onboarding.horseName"].waitForExistence(timeout: 20))
    app.buttons["Später"].tap()
    for title in ["Übersicht", "Durchsuchen", "Termine"] {
      XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 10), "Tab \(title) fehlt")
    }
    XCTAssertTrue(app.staticTexts["Noch keine Pferde"].exists)

    // Phase 7: without an iCloud entitlement the app runs and Settings say "noch nicht verfügbar" (SPEC 4.10).
    tapMenuItem("Einstellungen", in: app.buttons["profileMenu"])
    let syncStatus = app.descendants(matching: .any)["settings.syncStatus"].firstMatch
    scrollTo(syncStatus)
    XCTAssertTrue(syncStatus.label.contains("Noch nicht verfügbar"), "Sync-Status: \(syncStatus.label)")
    let explanation = text(containing: "bleiben alle Daten auf diesem Gerät")
    scrollTo(explanation)
    XCTAssertTrue(explanation.exists)
    attachScreenshot("Einstellungen iCloud")
  }

  /// Phase 1 acceptance: create two horses, switch, enter weight and temperature for each,
  /// chart with time ranges and reference band (F-PFERD-01, F-PFERD-02, F-MESS-01..04).
  func testTwoHorsesWithWeightAndTemperature() throws {
    launch()
    // Horse 1 via onboarding (NF-10 "Pferd anlegen").
    completeOnboarding(horseName: "Luna")

    // NF-10 "Messwert eintragen".
    addMeasurement("Gewicht", value: "540")
    addMeasurement("Körpertemperatur", value: "37,6")

    // Horse 2 via horse management.
    app.buttons["profileMenu"].tap()
    app.buttons["Pferdeverwaltung"].tap()
    app.buttons["addHorse"].tap()
    let horseName = app.textFields["horse.name"]
    XCTAssertTrue(horseName.waitForExistence(timeout: 5))
    enter("Max", into: horseName)
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
    turnOn(toggle)
    let lower = app.textFields["reference.lower"]
    XCTAssertTrue(lower.waitForExistence(timeout: 5))
    enter("500", into: lower)
    let upper = app.textFields["reference.upper"]
    enter("560", into: upper)
    app.buttons["save"].tap()
    XCTAssertTrue(text(containing: "Dein Bereich").waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Referenzbereich bearbeiten"].exists)

    attachScreenshot("Gewicht-Detail mit Referenzband")
  }
}

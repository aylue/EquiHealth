import XCTest

/// Phase 5 acceptance: for a stable in Germany a symptom from last year shows daily values; without
/// network there is no error dialog (F-WETTER-01 to -06, F-GESUND-05). Uses the stub provider of
/// `-uiTesting`; caching itself is covered by `WeatherTests` in EquiCore.
final class WeatherUITests: EquiUITestCase {
  func testSymptomFromLastYearShowsDailyWeather() throws {
    launch()
    setUpStableAndSymptomFromLastYear()

    let days = app.descendants(matching: .any).matching(identifier: "weather.day")
    let firstDay = days.firstMatch
    scrollTo(firstDay)
    XCTAssertEqual(days.count, 4, "Beginn und die 3 Tage davor")
    XCTAssertTrue(text(containing: "°C").exists, "Tageswerte mit Temperatur")
    XCTAssertTrue(text(containing: "Deutscher Wetterdienst").exists, "Quellenangabe")
    attachScreenshot("Symptom mit Wetter")

    // Timeline shows a weather line per day.
    app.buttons["Durchsuchen"].firstMatch.tap()
    let timeline = app.buttons["category.timeline"]
    XCTAssertTrue(timeline.waitForExistence(timeout: 5))
    timeline.tap()
    XCTAssertTrue(app.descendants(matching: .any)["weather.inline"].waitForExistence(timeout: 10))
    attachScreenshot("Zeitleiste mit Wetter")
  }

  func testOfflineShowsHintWithoutDialog() throws {
    launch(arguments: ["-weatherOffline"])
    setUpStableAndSymptomFromLastYear()

    let hint = text(containing: "nicht erreichbar")
    scrollTo(hint)
    XCTAssertTrue(hint.exists, "Dezenter Hinweis statt Fehlerdialog")
    XCTAssertEqual(app.alerts.count, 0, "Kein Fehlerdialog")
    attachScreenshot("Wetter offline")
  }

  /// Horse with a stable (coordinates in Münster) and an ongoing cough from last year; opens its detail.
  private func setUpStableAndSymptomFromLastYear() {
    let name = app.textFields["onboarding.horseName"]
    XCTAssertTrue(name.waitForExistence(timeout: 30))
    enter("Luna", into: name)
    app.buttons["onboarding.next"].tap()
    enter("Hof Sonnenschein", into: app.textFields.element(boundBy: 0))
    app.buttons["Weiter"].tap()
    let finish = app.buttons["onboarding.finish"]
    XCTAssertTrue(finish.waitForExistence(timeout: 5))
    finish.tap()

    // Stable location via manual coordinates.
    tapMenuItem("Ställe", in: app.buttons["profileMenu"])
    let stable = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Hof Sonnenschein'")).firstMatch
    XCTAssertTrue(stable.waitForExistence(timeout: 5))
    stable.tap()
    let manual = app.buttons["Koordinaten eingeben"].firstMatch
    scrollTo(manual)
    manual.tap()
    if !app.textFields["stable.latitude"].waitForExistence(timeout: 3) { manual.tap() }
    enter("51,96", into: app.textFields["stable.latitude"])
    enter("7,63", into: app.textFields["stable.longitude"])
    app.buttons["stable.applyCoordinates"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["stable.roundedCoordinate"].waitForExistence(timeout: 5))
    app.buttons["save"].tap()
    app.buttons["closeSheet"].tap()

    // Ongoing cough that started last year.
    openAddMenu("Symptom")
    pickPastDate(monthsBack: 12, day: 15, in: app.datePickers["symptom.start"])
    app.buttons["save"].tap()
    let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Husten'")).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
    XCTAssertTrue(app.staticTexts["Wetter am Beginn und den 3 Tagen davor"].waitForExistence(timeout: 10))
  }
}

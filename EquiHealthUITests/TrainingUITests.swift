import XCTest

/// Phase 8 acceptance: sample sessions from the debug menu appear per horse with week overview and
/// map (local store) (F-TRAIN-04, F-TRAIN-06).
final class TrainingUITests: EquiUITestCase {
  func testSampleSessionsShowWeekOverviewAndMap() throws {
    launch()
    completeOnboarding(horseName: "Luna")

    // Empty state before samples exist.
    app.buttons["Durchsuchen"].firstMatch.tap()
    let training = app.buttons["category.training"]
    scrollTo(training)
    training.tap()
    XCTAssertTrue(app.staticTexts["Keine Trainingseinheiten"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()

    // Debug menu (F-TRAIN-06).
    tapMenuItem("Einstellungen", in: app.buttons["profileMenu"])
    let create = app.buttons["developer.createTrainingSamples"]
    scrollTo(create)
    create.tap()
    let message = app.descendants(matching: .any)["developer.message"].firstMatch
    XCTAssertTrue(message.waitForExistence(timeout: 5))
    XCTAssertTrue(message.label.contains("Luna"), message.label)
    app.buttons["closeSheet"].tap()

    // Week overview and list (F-TRAIN-04).
    scrollTo(training)
    training.tap()
    let summary = app.descendants(matching: .any)["training.weekSummary"].firstMatch
    XCTAssertTrue(summary.waitForExistence(timeout: 5), "Wochenübersicht")
    XCTAssertTrue(summary.label.contains("Einheiten"), summary.label)
    XCTAssertTrue(app.staticTexts["Letzte 8 Wochen"].exists)
    attachScreenshot("Training Wochenübersicht")

    // A session with a route shows the map.
    let routed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Ausritt' OR label BEGINSWITH 'Reiten'"))
      .firstMatch
    scrollTo(routed)
    XCTAssertTrue(routed.exists, "Einheit mit Route vorhanden")
    routed.tap()
    XCTAssertTrue(app.descendants(matching: .any)["training.map"].firstMatch.waitForExistence(timeout: 10), "Karte")
    attachScreenshot("Training Detail mit Karte")
    let walk = app.descendants(matching: .any)["training.gait.walk"].firstMatch
    scrollTo(walk)
    XCTAssertTrue(walk.exists, "Gangarten im Detail")

    // Overview shows the last session (SPEC 5).
    app.buttons["Übersicht"].firstMatch.tap()
    let last = app.buttons["overview.lastTraining"].firstMatch
    scrollTo(last)
    XCTAssertTrue(last.exists, "Letzte Trainingseinheit in der Übersicht")
  }
}

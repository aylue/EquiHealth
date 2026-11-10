import XCTest

/// NF-04: with 10 horses over 10 years (≈ 50,000 entries) the main views open quickly and scroll
/// without hitches. Data comes from the debug generator; all values are written to the test log.
final class PerformanceUITests: EquiUITestCase {
  func testLargeDataSetStaysResponsive() throws {
    launch()
    completeOnboarding(horseName: "Luna")

    tapMenuItem("Einstellungen", in: app.buttons["profileMenu"])
    let generate = app.buttons["developer.generateLargeData"]
    scrollTo(generate)
    generate.tap()
    let message = app.descendants(matching: .any)["developer.message"].firstMatch
    XCTAssertTrue(message.waitForExistence(timeout: 300), "Testdaten werden erzeugt")
    XCTAssertTrue(message.label.contains("Einträge"), message.label)
    app.buttons["closeSheet"].tap()

    app.buttons["horseSwitcher"].tap()
    app.buttons["Testpferd 1"].firstMatch.tap()
    XCTAssertTrue(horseSwitcher(named: "Testpferd 1").waitForExistence(timeout: 5))

    // Measurement detail with all temperature values (≈ 1,800 points).
    app.buttons["Durchsuchen"].firstMatch.tap()
    timed("Messwerte") {
      app.buttons["category.measurements"].tap()
      return app.buttons.matching(NSPredicate(format: "label CONTAINS 'Körpertemperatur'")).firstMatch
    }.tap()
    XCTAssertTrue(app.descendants(matching: .any)["measurementChart"].firstMatch.waitForExistence(timeout: 5))
    timed("Temperatur „Alle“") {
      app.buttons["Alle"].firstMatch.tap()
      return app.descendants(matching: .any)["measurementChart"].firstMatch
    }
    scrollMeasured("Messwertliste", measured: true)
    attachScreenshot("NF-04 Temperatur alle")
    backToBrowse()

    // Timeline with ≈ 2,000 symptoms and treatments.
    let timeline = app.buttons["category.timeline"]
    scrollTo(timeline)
    timed("Zeitleiste") {
      timeline.tap()
      return app.buttons["timeline.symptom"].firstMatch
    }
    scrollMeasured("Zeitleiste")
    backToBrowse()

    // Feeding history over one year.
    let feeding = app.buttons["category.feeding"]
    scrollTo(feeding)
    feeding.tap()
    let history = app.buttons["feeding.history"].firstMatch
    XCTAssertTrue(history.waitForExistence(timeout: 5))
    history.tap()
    timed("Fütterung 1 Jahr") {
      app.buttons["1 Jahr"].firstMatch.tap()
      return app.buttons["1 Jahr"].firstMatch
    }
    attachScreenshot("NF-04 Fütterung 1 Jahr")
    backToBrowse()

    // Training with ≈ 1,500 sessions.
    let training = app.buttons["category.training"]
    scrollTo(training)
    timed("Training") {
      training.tap()
      return app.descendants(matching: .any)["training.weekSummary"].firstMatch
    }
    scrollMeasured("Trainingsliste")
  }

  /// Runs `action`, waits for the element it returns and fails if that took more than 5 seconds.
  /// The time includes XCUITest's own accessibility snapshot in a debug build on the simulator, so it
  /// is an upper bound; the work itself is measured in `LargeDataTests` (EquiCore).
  @discardableResult
  private func timed(_ label: String, _ action: () -> XCUIElement) -> XCUIElement {
    let start = Date.now
    let element = action()
    XCTAssertTrue(element.waitForExistence(timeout: 10), "\(label) erscheint")
    let seconds = Date.now.timeIntervalSince(start)
    print("NF-04 UI \(label): \(String(format: "%.2f", seconds)) s")
    XCTAssertLessThan(seconds, 5, "\(label) braucht zu lange")
    return element
  }

  /// Scrolls fast through the frontmost list; with `measured`, records scroll hitches (only once
  /// per test, an XCTest limit).
  private func scrollMeasured(_ label: String, measured: Bool = false) {
    let swipes = {
      for _ in 0..<4 { self.app.swipeUp(velocity: .fast) }
      for _ in 0..<4 { self.app.swipeDown(velocity: .fast) }
    }
    if measured {
      let options = XCTMeasureOptions()
      options.iterationCount = 1
      measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric], options: options) { swipes() }
    } else {
      let start = Date.now
      swipes()
      print(
        "NF-04 UI \(label) gescrollt: \(String(format: "%.1f", Date.now.timeIntervalSince(start))) s für 8 Wischgesten")
    }
  }

  private func backToBrowse() {
    app.buttons["Durchsuchen"].firstMatch.tap()
    app.buttons["Durchsuchen"].firstMatch.tap()
  }
}

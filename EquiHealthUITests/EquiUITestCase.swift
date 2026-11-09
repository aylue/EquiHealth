import XCTest

/// Shared helpers for EquiHealth UI tests (NF-10).
@MainActor
class EquiUITestCase: XCTestCase {
  var app: XCUIApplication!

  /// Starts the app with an empty in-memory store and German locale.
  /// `XCUIApplication` is created here (on the main actor), not in the test case initializer.
  func launch() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments += ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    app.launch()
  }

  /// Creates the first horse through the onboarding and skips the stable step.
  func completeOnboarding(horseName: String) {
    let name = app.textFields["onboarding.horseName"]
    XCTAssertTrue(name.waitForExistence(timeout: 30))
    enter(horseName, into: name)
    app.buttons["onboarding.next"].tap()
    app.buttons["onboarding.skip"].tap()
    XCTAssertTrue(horseSwitcher(named: horseName).waitForExistence(timeout: 10))
  }

  /// Taps a text field, waits until it has keyboard focus (retrying the tap once) and types.
  func enter(_ text: String, into field: XCUIElement) {
    scrollTo(field)
    let focused = NSPredicate(format: "hasKeyboardFocus == true")
    field.tap()
    if XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: focused, object: field)], timeout: 3) != .completed {
      field.tap()
      XCTAssertEqual(
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: focused, object: field)], timeout: 5),
        .completed, "Feld bekommt keinen Tastaturfokus")
    }
    field.typeText(text)
  }

  /// Scrolls the frontmost list until `element` is hittable.
  func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) {
    var swipes = 0
    while !(element.exists && element.isHittable) && swipes < maxSwipes {
      app.swipeUp(velocity: .slow)
      swipes += 1
    }
    XCTAssertTrue(element.waitForExistence(timeout: 3), "Element nicht gefunden: \(element)")
  }

  /// Turns a toggle on and verifies its value; taps the switch knob directly if needed.
  func turnOn(_ toggle: XCUIElement) {
    scrollTo(toggle)
    let isOn = NSPredicate(format: "value == '1'")
    for attempt in 0..<3 where (toggle.value as? String) != "1" {
      if attempt == 0 {
        toggle.switches.firstMatch.tap()
      } else {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
      }
      _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: isOn, object: toggle)], timeout: 2)
    }
    XCTAssertEqual(toggle.value as? String, "1", "Schalter \(toggle) ist nicht eingeschaltet")
  }

  /// Selects `option` in a menu-style picker.
  func choose(_ option: String, in picker: XCUIElement) {
    scrollTo(picker)
    picker.tap()
    let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", option)).firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 5), "Option \(option) fehlt")
    button.tap()
  }

  func horseSwitcher(named name: String) -> XCUIElement {
    app.buttons.matching(NSPredicate(format: "identifier == 'horseSwitcher' AND label CONTAINS %@", name))
      .firstMatch
  }

  func text(containing fragment: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
  }

  func openAddMenu(_ item: String) {
    app.buttons["addMenu"].tap()
    let button = app.buttons[item]
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    button.tap()
  }

  func addMeasurement(_ type: String, value: String) {
    openAddMenu("Messwert")
    app.buttons[type].tap()
    let field = app.textFields["measurement.value"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    enter(value, into: field)
    app.buttons["save"].tap()
    XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Sheet für \(type) schließt nicht")
  }

  func attachScreenshot(_ name: String) {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}

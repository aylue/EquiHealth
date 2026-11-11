import XCTest

/// Phase 9: English localisation (NF-08). The main navigation and a few screens appear in English.
@MainActor
final class EnglishUITests: XCTestCase {
  func testAppRunsInEnglish() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
    app.launch()

    let name = app.textFields["onboarding.horseName"]
    XCTAssertTrue(name.waitForExistence(timeout: 30))
    XCTAssertTrue(app.staticTexts["Step 1 of 3: Add horse"].exists)
    app.buttons["Later"].tap()
    for tab in ["Summary", "Browse", "Appointments"] {
      XCTAssertTrue(app.buttons[tab].firstMatch.waitForExistence(timeout: 10), "Tab \(tab)")
    }
    XCTAssertTrue(app.staticTexts["No Horses Yet"].exists)

    app.buttons["profileMenu"].tap()
    let settings = app.buttons["Settings"]
    XCTAssertTrue(settings.waitForExistence(timeout: 5))
    settings.tap()
    XCTAssertTrue(app.staticTexts["Reminders on this device"].waitForExistence(timeout: 5))
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Settings English"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}

import XCTest

/// Phase 0 acceptance: the app launches with the empty tab structure.
final class LaunchUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testLaunchShowsEmptyTabStructure() throws {
    let app = XCUIApplication()
    app.launchArguments += ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    app.launch()

    for title in ["Übersicht", "Durchsuchen", "Termine"] {
      XCTAssertTrue(app.buttons[title].firstMatch.waitForExistence(timeout: 10), "Tab \(title) fehlt")
    }
    XCTAssertTrue(app.staticTexts["Noch keine Pferde"].exists)

    app.buttons["Termine"].firstMatch.tap()
    XCTAssertTrue(app.staticTexts["Keine Termine"].waitForExistence(timeout: 5))
  }
}

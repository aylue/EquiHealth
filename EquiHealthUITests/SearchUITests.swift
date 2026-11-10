import XCTest

/// Full-text search (SPEC 5, Q-029): a symptom is found by its category and opens its detail.
final class SearchUITests: EquiUITestCase {
  func testSymptomIsFoundAndOpens() throws {
    launch()
    completeOnboarding(horseName: "Luna")
    openAddMenu("Symptom")
    app.buttons["save"].tap()
    XCTAssertTrue(app.buttons["save"].waitForNonExistence(timeout: 5))

    app.buttons["Suchen"].firstMatch.tap()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("hust")
    let hit = app.buttons["search.hit"].firstMatch
    XCTAssertTrue(hit.waitForExistence(timeout: 5), "Treffer erscheint")
    XCTAssertTrue(hit.label.contains("Husten") && hit.label.contains("Luna"), hit.label)
    attachScreenshot("Suche Treffer")
    hit.tap()
    XCTAssertTrue(app.navigationBars["Husten"].waitForExistence(timeout: 5), "Symptom-Detail öffnet sich")

    app.navigationBars.buttons.element(boundBy: 0).tap()
    field.tap()
    field.typeText("xyz")
    XCTAssertTrue(text(containing: "Keine Ergebnisse").waitForExistence(timeout: 5))
  }
}

import XCTest

/// Phase 3 acceptance: create a plan, change it, the day view shows the old plan for a day
/// before the change (F-FUTTER-01 to -05).
final class FeedingUITests: EquiUITestCase {
  func testPlanChangeKeepsOldPlanForEarlierDays() throws {
    launch()
    completeOnboarding(horseName: "Luna")

    // Feed master data (F-FUTTER-01).
    app.buttons["profileMenu"].tap()
    app.buttons["Futtermittel"].tap()
    let addFeed = app.buttons["feeds.add"]
    XCTAssertTrue(addFeed.waitForExistence(timeout: 5))
    addFeed.tap()
    enter("Heu", into: app.textFields["feed.name"])
    app.buttons["feed.save"].tap()
    XCTAssertTrue(text(containing: "Heu").waitForExistence(timeout: 5))
    app.buttons["closeSheet"].tap()

    // Plan valid from today: 8 kg hay ad libitum (F-FUTTER-02).
    app.buttons["Durchsuchen"].firstMatch.tap()
    let feeding = app.buttons["category.feeding"]
    XCTAssertTrue(feeding.waitForExistence(timeout: 5))
    feeding.tap()
    app.buttons["feeding.plan"].tap()
    app.buttons["plan.edit"].tap()
    let addLine = app.buttons["plan.addLine.adLibitum"]
    scrollTo(addLine)
    addLine.tap()
    enter("8", into: app.textFields["plan.amount"])
    app.buttons["plan.save"].tap()
    XCTAssertTrue(text(containing: "8 kg").waitForExistence(timeout: 5))

    // Change from tomorrow: 9 kg (F-FUTTER-03).
    app.buttons["plan.edit"].tap()
    replaceText("9", in: app.textFields["plan.amount"])
    pickDate(daysFromToday: 1, in: app.datePickers["plan.validFrom"])
    attachScreenshot("Plan ändern")
    app.buttons["plan.save"].tap()
    XCTAssertTrue(app.buttons["plan.edit"].waitForExistence(timeout: 5))
    XCTAssertEqual(
      app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'gültig ab'")).count, 2, "Zwei Planversionen")
    XCTAssertTrue(text(containing: "8 kg").exists, "Heute gilt noch der alte Plan")
    XCTAssertTrue(app.buttons["plan.upcoming"].exists, "Hinweis auf den künftigen Plan")
    attachScreenshot("Futterplan mit Versionen")

    // Day view (F-FUTTER-05): today (before the change) old plan, tomorrow new plan.
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.buttons["feeding.day"].tap()
    XCTAssertTrue(text(containing: "8 kg").waitForExistence(timeout: 5))
    XCTAssertFalse(text(containing: "9 kg").exists)

    // Additional feeding today (F-FUTTER-04).
    app.buttons["day.addLog"].tap()
    choose("Heu", in: app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Futtermittel'")).firstMatch)
    enter("1,5", into: app.textFields["log.amount"])
    app.buttons["save"].tap()
    XCTAssertTrue(text(containing: "1,5 kg").waitForExistence(timeout: 5))
    attachScreenshot("Fütterung heute")

    app.buttons["day.next"].tap()
    XCTAssertTrue(text(containing: "9 kg").waitForExistence(timeout: 5))
    XCTAssertFalse(text(containing: "8 kg").exists)
    XCTAssertFalse(text(containing: "1,5 kg").exists, "Zusatzgabe gehört nur zu ihrem Tag")
    attachScreenshot("Fütterung morgen")

    app.buttons["day.previous"].tap()
    app.buttons["day.previous"].tap()
    XCTAssertTrue(text(containing: "kein Futterplan").waitForExistence(timeout: 5))
  }
}

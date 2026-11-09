import XCTest

/// NF-10 "Export": CSV files in both formats and a backup are created. Saving to Files uses the
/// system document picker and is not automated; file contents are covered by EquiCore tests.
final class ExportUITests: EquiUITestCase {
  func testCSVExportInBothFormatsAndBackup() throws {
    launch()
    completeOnboarding(horseName: "Lünä")
    addMeasurement("Gewicht", value: "540,5")

    tapMenuItem("Einstellungen", in: app.buttons["profileMenu"])
    let csv = app.buttons["settings.csvExport"]
    scrollTo(csv)
    csv.tap()

    for format in ["Excel (Deutsch)", "Standard"] {
      let segment = app.buttons[format].firstMatch
      scrollTo(segment)
      segment.tap()
      let create = app.buttons["export.create"]
      scrollTo(create)
      create.tap()
      let measurements = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS 'Messwerte.csv'")).firstMatch
      scrollTo(measurements)
      XCTAssertTrue(measurements.label.contains("1 Zeile"), "Ein Messwert: \(measurements.label)")
      let save = app.buttons["export.save"]
      scrollTo(save)
      XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "export.file").count >= 5, "Dateiliste")
      let training = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS 'Trainingseinheiten.csv'")).firstMatch
      XCTAssertTrue(training.exists, "Neunte Datei vorhanden")
      attachScreenshot("CSV \(format)")
    }

    app.navigationBars.buttons.element(boundBy: 0).tap()
    let backup = app.buttons["settings.backup"]
    scrollTo(backup)
    backup.tap()
    XCTAssertTrue(text(containing: "noch keins").waitForExistence(timeout: 5))
    app.buttons["backup.create"].tap()
    let summary = app.descendants(matching: .any)["backup.summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 10))
    XCTAssertTrue(summary.label.contains("1 Pferde"), "Inhalt: \(summary.label)")
    XCTAssertTrue(app.buttons["backup.save"].exists)
    attachScreenshot("Backup erstellt")
  }
}

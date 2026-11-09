import XCTest

/// Phase 2 acceptance: record a colic with details and photo, link it to a vet visit with a
/// medication, everything appears in the timeline (F-GESUND-01, -03, -06, F-BEH-01, -03, -05, -08).
final class HealthUITests: EquiUITestCase {
  func testColicWithVetVisitAndMedicationAppearsInTimeline() throws {
    launch()
    completeOnboarding(horseName: "Luna")

    // Vet visit with new contact and a medication with food withdrawal of 5 days.
    openAddMenu("Behandlung")
    let newContact = app.buttons["treatment.newContact"]
    XCTAssertTrue(newContact.waitForExistence(timeout: 5))
    newContact.tap()
    enter("Dr. Weber", into: app.textFields["contact.name"])
    app.buttons["contact.save"].tap()
    XCTAssertTrue(text(containing: "Dr. Weber").waitForExistence(timeout: 5), "Neuer Kontakt ist ausgewählt")
    enter("Kolik-Untersuchung", into: app.textFields["treatment.description"])

    let addMedication = app.buttons["treatment.addMedication"]
    scrollTo(addMedication)
    addMedication.tap()
    enter("Flunixin", into: app.textFields["medication.product"])
    choose(
      "Tage ab letzter Gabe", in: app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Angabe'")).firstMatch)
    enter("5", into: app.textFields["medication.foodDays"])
    app.buttons["medication.save"].tap()
    XCTAssertTrue(text(containing: "Flunixin").waitForExistence(timeout: 5))
    app.buttons["save"].tap()
    XCTAssertTrue(app.buttons["addMenu"].waitForExistence(timeout: 5))

    // Colic with details, photo and link to the vet visit.
    openAddMenu("Symptom")
    choose("Kolik", in: app.buttons["symptom.category"])
    app.buttons["schwer"].tap()
    turnOn(app.switches["colic.pawing"])
    turnOn(app.switches["colic.vetCalled"])
    choose("Tierarztbesuch", in: app.buttons["symptom.treatment"])

    // The system photo picker runs out of process; the debug-only test button adds a photo
    // through the same draft path (see AttachmentEditorSection).
    let addPhoto = app.buttons["attachments.addTestPhoto"]
    scrollTo(addPhoto)
    addPhoto.tap()
    XCTAssertTrue(app.descendants(matching: .any)["attachment.thumbnail"].waitForExistence(timeout: 5))
    attachScreenshot("Kolik-Formular")
    app.buttons["save"].tap()
    XCTAssertTrue(app.buttons["save"].waitForNonExistence(timeout: 5), "Symptom-Formular schließt nicht")

    // Overview: ongoing symptom and running food withdrawal (F-GESUND-03, F-BEH-09).
    XCTAssertTrue(app.buttons["endSymptom"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["withdrawal.food"].exists)
    attachScreenshot("Übersicht mit laufender Kolik")

    // Timeline (F-GESUND-06).
    app.buttons["Durchsuchen"].firstMatch.tap()
    let timeline = app.buttons["category.timeline"]
    XCTAssertTrue(timeline.waitForExistence(timeout: 5))
    timeline.tap()
    XCTAssertTrue(app.buttons["timeline.symptom"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["timeline.treatment"].exists)
    XCTAssertTrue(text(containing: "Flunixin").exists, "Medikament erscheint an der Behandlung")
    attachScreenshot("Zeitleiste")

    // Symptom detail with details, photo and linked treatment.
    app.buttons["timeline.symptom"].tap()
    XCTAssertTrue(text(containing: "Scharren").waitForExistence(timeout: 5))
    XCTAssertTrue(text(containing: "Tierarzt gerufen").exists)
    let thumbnail = app.descendants(matching: .any)["attachment.thumbnail"]
    scrollTo(thumbnail)
    XCTAssertTrue(thumbnail.exists, "Foto erscheint im Detail")
    attachScreenshot("Kolik-Detail")
    let linked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tierarztbesuch'")).firstMatch
    scrollTo(linked)
    linked.tap()
    XCTAssertTrue(text(containing: "Wartezeit Lebensmittel bis").waitForExistence(timeout: 5))
    XCTAssertTrue(text(containing: "Dr. Weber").exists)
    attachScreenshot("Tierarztbesuch-Detail")
  }
}

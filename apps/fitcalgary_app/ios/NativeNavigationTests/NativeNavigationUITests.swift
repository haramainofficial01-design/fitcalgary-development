import XCTest

final class NativeNavigationUITests: XCTestCase {
  func testNativeTabsOpenTheirActualProductScreens() {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "ca.fitcalgary.index")
    app.launch()
    if app.buttons["NEXT →"].waitForExistence(timeout: 3) {
      app.buttons["NEXT →"].tap()
      app.buttons["NEXT →"].tap()
      app.buttons["EXPLORE FITCALGARY"].tap()
    }
    XCTAssertTrue(app.buttons["Gyms"].waitForExistence(timeout: 10))
    app.buttons["Gyms"].tap()
    XCTAssertTrue(app.staticTexts["Every major gym\nin Calgary."].waitForExistence(timeout: 10))
    app.buttons["Board"].tap()
    let officialFilter = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", "Official · verified")).firstMatch
    XCTAssertTrue(officialFilter.waitForExistence(timeout: 10))
    app.buttons["Compete"].tap()
    XCTAssertTrue(app.staticTexts["Calgary\ncompetitions."].waitForExistence(timeout: 10))
    app.buttons["Me"].tap()
    XCTAssertTrue(app.staticTexts["Your fitness\nidentity."].waitForExistence(timeout: 10))
    app.buttons["Home"].tap()
    for _ in 0..<6 {
      if app.buttons["POST A RESULT →"].exists { break }
      app.swipeUp()
    }
    XCTAssertTrue(app.buttons["POST A RESULT →"].waitForExistence(timeout: 10))
    let capture = XCTAttachment(screenshot: app.screenshot())
    capture.name = "FitCalgary native navigation"
    capture.lifetime = .keepAlways
    add(capture)
  }
}

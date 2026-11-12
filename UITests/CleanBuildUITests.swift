import XCTest

final class CleanBuildUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.activate()
    }

    func testPrimaryNavigationAndEmptyState() {
        XCTAssertTrue(app.staticTexts["Find space used by development tools"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Scan Mac"].exists || app.buttons["Scan Again"].exists)
        app.staticTexts["Storage Explorer"].click()
        XCTAssertTrue(app.staticTexts["Storage Explorer"].waitForExistence(timeout: 2))
        app.staticTexts["History"].click()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 2))
        app.staticTexts["Settings"].click()
        XCTAssertTrue(app.staticTexts["Scan Locations"].waitForExistence(timeout: 2))
    }

    func testKeyboardRescanCommandIsAvailable() {
        app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3) || app.buttons["Scan Again"].waitForExistence(timeout: 3))
    }

    func testEmptyExplorerHidesIrrelevantControls() {
        XCTAssertTrue(app.staticTexts["Find space used by development tools"].waitForExistence(timeout: 5))
        app.activate()
        let storageExplorer = app.staticTexts["Storage Explorer"].firstMatch
        XCTAssertTrue(storageExplorer.waitForExistence(timeout: 2))
        storageExplorer.click()
        XCTAssertTrue(app.buttons["Scan Mac"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.searchFields["Search name or path"].exists)
        XCTAssertFalse(app.buttons["Review Cleanup…"].exists)
        XCTAssertFalse(app.popUpButtons["All Safety Levels"].exists)
    }
}

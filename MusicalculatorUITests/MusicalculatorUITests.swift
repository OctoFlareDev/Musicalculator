//
//  MusicalculatorUITests.swift
//  MusicalculatorUITests
//
//  Created by Flare ​ on 7/8/26.
//

import XCTest

final class MusicalculatorUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testToolbarActionsSurviveRepeatedLayoutChanges() throws {
        let app = XCUIApplication()
        let originalOrientation = XCUIDevice.shared.orientation
        defer { XCUIDevice.shared.orientation = originalOrientation }
        app.launch()

        let writing = app.switches["writeNotesToggle"]
        XCTAssertTrue(writing.waitForExistence(timeout: 5))
        writing.tap()
        app.buttons["5"].firstMatch.tap()

        // On the Duo inner display these rotations move the same controls between
        // horizontal and vertical bars. Actual hinge poses also need Device Hub QA.
        for orientation: UIDeviceOrientation in [.landscapeLeft, .portrait, .landscapeRight, .portrait, .landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation

            let navigation = app.buttons["navigationMenu"]
            XCTAssertTrue(navigation.waitForExistence(timeout: 5))
            XCTAssertTrue(navigation.isHittable)
            navigation.tap()
            XCTAssertTrue(app.buttons["Calculator"].waitForExistence(timeout: 3))
            app.buttons["Calculator"].tap()
            XCTAssertTrue(app.staticTexts["calculatorDisplay"].waitForExistence(timeout: 3))
            app.buttons["navigationMenu"].tap()
            app.buttons["Play"].tap()

            // A working save action proves the composition survived and that the
            // toolbar still delivers touches, rather than merely exposing AX nodes.
            let save = app.buttons["saveSongButton"]
            XCTAssertTrue(save.waitForExistence(timeout: 3))
            XCTAssertTrue(save.isHittable)
            save.press(forDuration: 0.8)
            let saveAs = app.buttons["saveAsAction"]
            XCTAssertTrue(saveAs.waitForExistence(timeout: 3))
            saveAs.tap()
            XCTAssertTrue(app.alerts["Save song"].waitForExistence(timeout: 3))
            app.alerts.buttons["Cancel"].tap()

            // The first tap after a long press must work, too.
            save.tap()
            XCTAssertTrue(app.alerts["Save song"].waitForExistence(timeout: 3))
            app.alerts.buttons["Cancel"].tap()
            XCTAssertTrue(app.buttons["playbackButton"].isHittable)
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

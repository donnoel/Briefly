//
//  BrieflyUITests.swift
//  BrieflyUITests
//
//  Created by Don Noel on 11/30/25.
//

import XCTest

final class BrieflyUITests: XCTestCase {

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
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testStudyFlowPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedTopic"]
        app.launch()

        let topicCard = app.descendants(matching: .any)["library.topic.card"].firstMatch
        guard topicCard.waitForExistence(timeout: 20) else {
            throw XCTSkip("No topic cards available for study-flow performance test.")
        }
        app.terminate()

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(metrics: [XCTClockMetric()], options: options) {
            app.launch()
            runStudyFlow(in: app)
            app.terminate()
        }
    }

    @MainActor
    private func runStudyFlow(in app: XCUIApplication) {
        app.swipeUp()
        app.swipeDown()

        let topicCard = app.descendants(matching: .any)["library.topic.card"].firstMatch
        XCTAssertTrue(topicCard.waitForExistence(timeout: 20), "Expected at least one topic card in library.")
        topicCard.tap()

        let sectionCard = app.descendants(matching: .any)["topic.section.card"].firstMatch
        XCTAssertTrue(sectionCard.waitForExistence(timeout: 10), "Expected at least one section card in topic detail.")
        sectionCard.tap()

        let seeAnswerButton = app.buttons["See answer"].firstMatch
        XCTAssertTrue(seeAnswerButton.waitForExistence(timeout: 5), "Expected deck screen to appear.")
        seeAnswerButton.tap()
    }
}

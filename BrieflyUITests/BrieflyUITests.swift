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
        let app = makeSeededApp()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeSeededApp().launch()
        }
    }

    @MainActor
    func testStudyFlowPerformance() throws {
        let app = makePerfApp()
        assertSeededTopicExists(in: app)

        let options = perfMeasureOptions()
        measure(metrics: [XCTClockMetric()], options: options) {
            app.launch()
            runStudyFlow(in: app)
            app.terminate()
        }
    }

    @MainActor
    func testLibraryToTopicNavigationPerformance() throws {
        let app = makePerfApp()
        assertSeededTopicExists(in: app)

        let options = perfMeasureOptions()
        measure(metrics: [XCTClockMetric()], options: options) {
            app.launch()
            openFirstTopic(in: app)
            app.terminate()
        }
    }

    @MainActor
    func testTopicToDeckNavigationPerformance() throws {
        let app = makePerfApp()
        assertSeededTopicExists(in: app)

        let options = perfMeasureOptions()
        measure(metrics: [XCTClockMetric()], options: options) {
            app.launch()
            openFirstTopic(in: app)
            openFirstSectionInTopic(in: app)
            app.terminate()
        }
    }

    @MainActor
    func testCompletingSeededSectionPersistsAfterRelaunch() throws {
        var app = makeSeededApp(resetState: true)
        app.launch()

        openFirstTopic(in: app)
        openFirstSectionInTopic(in: app)
        finishCurrentSection(in: app)

        XCTAssertTrue(
            app.staticTexts["Section complete"].waitForExistence(timeout: 5),
            "Expected the deck to show section completion after finishing the seeded card."
        )

        app.terminate()

        app = makeSeededApp()
        app.launch()

        openFirstTopic(in: app)

        XCTAssertTrue(
            app.staticTexts["Completed"].waitForExistence(timeout: 10),
            "Expected section completion to persist after relaunch."
        )
        XCTAssertTrue(
            app.staticTexts["Review again"].waitForExistence(timeout: 5),
            "Expected the completed section to remain available for review after relaunch."
        )

        app.terminate()
    }

    @MainActor
    func testCannedGeneratedPackCanBeReviewedSavedAndReloaded() throws {
        let generatedTitle = "UI Canned Generated Pack"
        var app = makeSeededApp(resetState: true, useCannedGeneratedPack: true)
        app.launch()

        openGenerationSheet(in: app)

        XCTAssertTrue(
            app.staticTexts["Review & Edit"].waitForExistence(timeout: 5),
            "Expected canned generation to open review without waiting on the network."
        )
        XCTAssertTrue(
            app.textFields[generatedTitle].waitForExistence(timeout: 5),
            "Expected review UI to contain the canned generated pack title."
        )

        let saveButton = app.buttons["generated.review.save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Expected review UI to expose the save action.")
        saveButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[generatedTitle].waitForExistence(timeout: 10),
            "Expected saved generated pack to appear in the library."
        )

        app.terminate()

        app = makeSeededApp(useCannedGeneratedPack: true)
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)[generatedTitle].waitForExistence(timeout: 20),
            "Expected saved generated pack to persist after relaunch."
        )

        app.terminate()
    }

    @MainActor
    private func runStudyFlow(in app: XCUIApplication) {
        app.swipeUp()
        app.swipeDown()

        openFirstTopic(in: app)
        openFirstSectionInTopic(in: app)

        submitCurrentAnswer(in: app)
    }

    @MainActor
    private func openFirstTopic(in app: XCUIApplication) {
        let topicCard = app.descendants(matching: .any)["library.topic.card"].firstMatch
        XCTAssertTrue(topicCard.waitForExistence(timeout: 20), "Expected at least one topic card in library.")
        topicCard.tap()
    }

    @MainActor
    private func openFirstSectionInTopic(in app: XCUIApplication) {
        let sectionCard = app.descendants(matching: .any)["topic.section.card"].firstMatch
        XCTAssertTrue(sectionCard.waitForExistence(timeout: 10), "Expected at least one section card in topic detail.")
        sectionCard.tap()
    }

    @MainActor
    private func openGenerationSheet(in app: XCUIApplication) {
        let createTopicButton = app.buttons["Create Topic"].firstMatch
        XCTAssertTrue(createTopicButton.waitForExistence(timeout: 20), "Expected library create topic action to appear.")
        createTopicButton.tap()
    }

    @MainActor
    private func submitCurrentAnswer(in app: XCUIApplication) {
        let answerButton = app.buttons["deck.answer.option.correct"].firstMatch
        XCTAssertTrue(answerButton.waitForExistence(timeout: 5), "Expected deck screen to show the correct answer option.")
        answerButton.tap()
    }

    @MainActor
    private func finishCurrentSection(in app: XCUIApplication) {
        submitCurrentAnswer(in: app)

        let finishButton = app.buttons["Finish section"].firstMatch
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5), "Expected final card to expose the finish action.")
        finishButton.tap()
    }

    @MainActor
    private func assertSeededTopicExists(in app: XCUIApplication) {
        app.launch()
        let topicCard = app.descendants(matching: .any)["library.topic.card"].firstMatch
        XCTAssertTrue(topicCard.waitForExistence(timeout: 20), "Expected a seeded topic card for UI performance tests.")
        app.terminate()
    }

    private func makePerfApp() -> XCUIApplication {
        makeSeededApp()
    }

    private func makeSeededApp(resetState: Bool = false, useCannedGeneratedPack: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedTopic", "-uiTestDisableCloudSync"]
        if resetState {
            app.launchArguments += ["-uiTestResetState"]
        }
        if useCannedGeneratedPack {
            app.launchArguments += ["-uiTestUseCannedGeneratedPack"]
        }
        return app
    }

    private func perfMeasureOptions() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        return options
    }
}

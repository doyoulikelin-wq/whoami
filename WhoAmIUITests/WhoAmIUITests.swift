import XCTest

final class WhoAmIUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A first launch must reach recording directly and preserve the result across launches.
    @MainActor
    func testRecordIsAvailableInTodayAndJournalAndPersistsAfterRelaunch() {
        launchFresh(empty: true)
        capture("01_First_launch_without_gate")

        let marker = uniqueTitle("Persist")
        let body = "\(marker)\nI made one small step on my own project today."
        openComposer()
        composerInput.typeText(body)
        capture("02_Composer_with_real_record")
        saveComposer()

        reveal(text(containing: marker))
        XCTAssertTrue(text(containing: marker).isHittable, "The saved entry should be available on Today.")
        capture("03_Today_with_saved_record")

        selectTab("日记")
        XCTAssertTrue(app.textFields["journal.search"].waitForExistence(timeout: 5))
        reveal(text(containing: marker))
        capture("04_Journal_with_saved_record")

        app.terminate()
        app.launchArguments = [] // Do not reset storage on the second launch.
        app.launch()
        XCTAssertTrue(app.buttons["compose-primary"].waitForExistence(timeout: 10))
        selectTab("日记")
        reveal(text(containing: marker))
        text(containing: marker).tap()
        XCTAssertTrue(app.navigationBars["原始记录"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(containing: "I made one small step on my own project today.").exists)
        capture("05_Record_reloaded_from_local_storage")
    }

    /// Dismissing the composer preserves its draft; saving consumes that draft once.
    @MainActor
    func testDismissedDraftCanBeResumedAndSaved() {
        launchFresh(empty: true)
        let marker = uniqueTitle("Draft")
        let body = "\(marker)\nI want to come back to this unfinished thought."

        openComposer()
        composerInput.typeText(body)
        app.buttons["dismiss-composer"].tap()
        waitUntilGone(composerInput)

        let resumeButton = app.buttons["compose-primary"]
        reveal(resumeButton)
        XCTAssertTrue(resumeButton.label.contains("继续草稿"))
        capture("06_Draft_is_ready_to_resume")
        resumeButton.tap()
        XCTAssertTrue(composerInput.waitForExistence(timeout: 5))
        XCTAssertEqual(composerInput.value as? String, body)
        capture("07_Restored_draft")
        saveComposer()

        selectTab("日记")
        reveal(text(containing: marker))
        XCTAssertTrue(text(containing: marker).isHittable)
        capture("08_Draft_saved_as_journal_entry")

        app.buttons["compose-toolbar"].tap()
        XCTAssertTrue(composerInput.waitForExistence(timeout: 5))
        XCTAssertEqual(composerInput.value as? String, "")
        XCTAssertFalse(app.buttons["save-entry"].isEnabled, "A saved draft must not be duplicated by saving an empty composer.")
        app.buttons["dismiss-composer"].tap()
        waitUntilGone(composerInput)
    }

    /// Exercise all four native tabs and follow a review's evidence to its original record.
    @MainActor
    func testFourTabsAndExampleReviewEvidenceAreNavigable() {
        launchFresh(empty: false)
        XCTAssertTrue(app.staticTexts["观察自己"].waitForExistence(timeout: 5))
        capture("09_Today_examples")

        selectTab("日记")
        XCTAssertTrue(app.textFields["journal.search"].waitForExistence(timeout: 5))
        reveal(text(containing: "先验证，再扩展"))
        capture("10_Journal_examples")

        let profileTab = selectTab("我的")
        XCTAssertTrue(profileTab.isSelected, "The native profile tab should be selected.")
        capture("11_Profile")

        selectTab("今天")
        reveal(app.buttons["compose-primary"], swipingUp: false)
        XCTAssertTrue(app.buttons["compose-primary"].isHittable)

        selectTab("复盘")
        XCTAssertTrue(app.staticTexts["检视变化"].waitForExistence(timeout: 5))
        capture("12_Review_home")

        let latestReview = identified("review.latest")
        reveal(latestReview)
        latestReview.tap()
        XCTAssertTrue(app.navigationBars["复盘示例"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(containing: "以下为虚构的复盘示例").exists)
        capture("13_Example_review_detail")

        let evidence = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "review.evidence.")).firstMatch
        reveal(evidence, maxSwipes: 12)
        XCTAssertTrue(app.staticTexts["原始依据"].exists)
        capture("14_Review_original_evidence")
        evidence.tap()

        XCTAssertTrue(app.navigationBars["原始记录"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["原始记录"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["示例内容"].exists)
        XCTAssertTrue(text(containing: "今天用一个可操作的页面验证记录流程。").exists)
        capture("15_Original_record_opened_from_review")

        selectTab("今天")
        reveal(app.buttons["compose-primary"], swipingUp: false)
    }

    /// Editing is isolated until Save; committed edits and deletion change the real journal.
    @MainActor
    func testEditingCanBeCancelledThenSavedAndRecordCanBeDeleted() {
        launchFresh(empty: true)
        let suffix = String(UUID().uuidString.prefix(6))
        let originalTitle = "Before-\(suffix)"
        let savedTitle = "After-\(suffix)"
        let originalBody = "\(originalTitle)\nOriginal source."
        let savedBody = "Edited source remains local."

        openComposer()
        composerInput.typeText(originalBody)
        saveComposer()
        selectTab("日记")
        reveal(text(containing: originalTitle))
        text(containing: originalTitle).tap()
        XCTAssertTrue(app.buttons["journal.edit"].waitForExistence(timeout: 5))

        app.buttons["journal.edit"].tap()
        let titleInput = identified("journal.edit.title")
        XCTAssertTrue(titleInput.waitForExistence(timeout: 5))
        replaceText(in: titleInput, with: "Discarded")
        app.navigationBars["编辑记录"].buttons["取消"].tap()
        waitUntilGone(titleInput)
        XCTAssertTrue(app.staticTexts[originalTitle].exists)
        XCTAssertFalse(app.staticTexts["Discarded"].exists)

        app.buttons["journal.edit"].tap()
        XCTAssertTrue(titleInput.waitForExistence(timeout: 5))
        replaceText(in: titleInput, with: savedTitle)
        replaceText(in: identified("journal.edit.body"), with: savedBody)
        app.buttons["journal.edit.save"].tap()
        waitUntilGone(titleInput)
        XCTAssertTrue(app.staticTexts[savedTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[savedBody].exists)
        capture("16_Saved_edits")

        app.buttons["记录操作"].tap()
        app.buttons["删除记录"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["删除这条记录？"].waitForExistence(timeout: 5))
        capture("17_Delete_confirmation")
        app.buttons["删除记录"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["暂无记录"].waitForExistence(timeout: 5))
        XCTAssertFalse(text(containing: savedTitle).exists)
        capture("18_Empty_journal_after_deletion")
    }

    /// A local review excludes examples and reloads committed feedback and action status.
    @MainActor
    func testLocalReviewUsesOnlyRealEntriesAndCanSaveFeedback() {
        launchFresh(empty: false) // Keep the seeded examples alongside one real entry.
        let marker = uniqueTitle("Real")
        let feedback = "Useful next step."
        openComposer()
        composerInput.typeText("\(marker)\nOne real event.")
        saveComposer()

        selectTab("复盘")
        let createReview = app.buttons["review.createLocal"]
        reveal(createReview)
        createReview.tap()
        XCTAssertTrue(app.navigationBars["回顾详情"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本地回顾"].exists)
        XCTAssertTrue(text(containing: "留下了 1 条记录").exists)

        let evidence = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "review.evidence."))
        reveal(evidence.firstMatch)
        XCTAssertEqual(evidence.count, 1, "Only the real entry should become review evidence.")
        XCTAssertTrue(evidence.firstMatch.label.contains(marker))
        XCTAssertTrue(text(containing: "One real event.").exists)
        XCTAssertFalse(evidence.matching(NSPredicate(format: "label CONTAINS %@", "先验证，再扩展")).firstMatch.exists)
        capture("19_Local_review")

        let actionDone = app.switches["review.actionDone"]
        reveal(actionDone)
        XCTAssertEqual(actionDone.value as? String, "0")
        actionDone.tap()
        XCTAssertEqual(actionDone.value as? String, "1")

        let feedbackInput = identified("review.feedback")
        reveal(feedbackInput)
        feedbackInput.tap()
        feedbackInput.typeText(feedback)
        app.buttons["完成"].firstMatch.tap()
        let saveFeedback = app.buttons["review.save"]
        reveal(saveFeedback)
        saveFeedback.tap()
        let savedIndicator = identified("review.saved")
        XCTAssertTrue(savedIndicator.waitForExistence(timeout: 5))
        reveal(savedIndicator)
        capture("20_Feedback_saved")

        app.navigationBars["回顾详情"].buttons.element(boundBy: 0).tap()
        let latestReview = identified("review.latest")
        reveal(latestReview)
        latestReview.tap()
        XCTAssertTrue(app.navigationBars["回顾详情"].waitForExistence(timeout: 5))
        reveal(feedbackInput)
        XCTAssertEqual(feedbackInput.value as? String, feedback)
        XCTAssertEqual(actionDone.value as? String, "1")

        selectTab("今天")
        reveal(app.buttons["compose-primary"], swipingUp: false)
    }

    @MainActor
    private var composerInput: XCUIElement {
        app.textViews["entry-body-input"]
    }

    @MainActor
    private func launchFresh(empty: Bool) {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset"]
        if empty { app.launchArguments.append("--uitesting-empty") }
        app.launch()
        XCTAssertTrue(app.buttons["compose-primary"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func openComposer() {
        let button = app.buttons["compose-primary"]
        reveal(button)
        button.tap()
        XCTAssertTrue(composerInput.waitForExistence(timeout: 5))
        composerInput.tap()
    }

    @MainActor
    private func saveComposer() {
        let saveButton = app.buttons["save-entry"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()
        waitUntilGone(composerInput)
    }

    @MainActor
    private func identified(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    /// Prefer UITabBar descendants; the global button fallback also handles floating tab bars.
    @MainActor
    @discardableResult
    private func selectTab(_ label: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let tabBarButton = app.tabBars.buttons[label].firstMatch
        let fallbackButton = app.buttons[label].firstMatch
        for _ in 0..<4 {
            let button = tabBarButton.exists ? tabBarButton : fallbackButton
            if button.exists && button.isHittable {
                button.tap()
                return button
            }
            // A downward content gesture expands the iOS floating tab bar after scrolling.
            app.swipeDown()
        }
        XCTFail("Could not reach the \(label) tab.", file: file, line: line)
        return fallbackButton
    }

    /// Use the outer scroll view and stay away from the floating tab bar while scrolling.
    @MainActor
    private func reveal(_ element: XCUIElement, maxSwipes: Int = 9, swipingUp: Bool = true,
                        file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0...maxSwipes {
            if element.exists && element.isHittable { return }
            let scrollView = app.scrollViews.firstMatch
            let surface = scrollView.exists ? scrollView : app!
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: swipingUp ? 0.75 : 0.3))
            let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: swipingUp ? 0.3 : 0.75))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture("Unable_to_reveal_element")
        XCTFail("The expected element did not become visible: \(element)", file: file, line: line)
    }

    @MainActor
    private func replaceText(in element: XCUIElement, with replacement: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let previous = element.value as? String ?? ""
        // These fixtures fit in a few short lines. Tapping their lower trailing edge puts
        // the caret after the content without depending on localized edit-menu labels.
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        element.typeText(replacement)
        XCTAssertEqual(element.value as? String, replacement)
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, file: file, line: line)
    }

    private func uniqueTitle(_ prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.prefix(8))"
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

import XCTest

final class WhoAmIUITests: XCTestCase {
    private var app: XCUIApplication!

    private let domains: [(id: String, title: String)] = [
        ("career", "事业与创造"), ("finance", "财务与资源"), ("body", "身体与精力"),
        ("emotion", "情绪与应对"), ("learning", "学习与认知"),
        ("relationships", "关系与边界"), ("life", "生活与自主")
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testThreeTabsAndWheelProvideDirectRecordingWithoutOldComposer() {
        launchFresh()
        capture("30_Dashboard")
        XCTAssertFalse(app.buttons["compose-primary"].exists)
        XCTAssertFalse(app.buttons["compose-toolbar"].exists)

        selectTab("记录")
        XCTAssertTrue(identified("record-view").waitForExistence(timeout: 5))
        XCTAssertTrue(recordInput.exists)
        XCTAssertTrue(app.buttons["record-voice"].exists)
        XCTAssertFalse(app.buttons["record-save"].isEnabled)
        selectDomain("career", title: "事业与创造")
        capture("31_Wheel_record")

        let title = identified("record-domain-title")
        let previousTitle = title.label
        let wheel = identified("dimension-wheel")
        reveal(wheel, swipingUp: false)
        wheel.swipeLeft()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", previousTitle), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed,
                       "A horizontal wheel gesture should change the selected domain.")

        selectTab("对比")
        XCTAssertTrue(identified("comparison-view").waitForExistence(timeout: 5))
        XCTAssertEqual(comparisonRows.count, 0)
        selectTab("总览")
        XCTAssertTrue(identified("dashboard-view").waitForExistence(timeout: 5))
    }

    @MainActor
    func testSevenDomainDraftsPersistSeparatelyAndEachCanBeSaved() {
        launchFresh()
        selectTab("记录")
        for domain in domains {
            selectDomain(domain.id, title: domain.title)
            XCTAssertEqual(recordInput.value as? String, "", "A new domain should have its own empty draft.")
            enterRecord("Draft-\(domain.id)")
        }

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(identified("dashboard-view").waitForExistence(timeout: 10))
        selectTab("记录")

        for domain in domains {
            selectDomain(domain.id, title: domain.title)
            XCTAssertEqual(recordInput.value as? String, "Draft-\(domain.id)")
            saveRecord()
            let sector = app.buttons["wheel.domain.\(domain.id)"]
            XCTAssertTrue(sector.label.contains("已记录"), "Each saved domain should have an accessible saved marker.")
        }

        capture("38_All_dimensions_saved")
        selectTab("对比")
        XCTAssertTrue(identified("comparison-view").waitForExistence(timeout: 5))
        for domain in domains.reversed() {
            let row = comparisonRow(forDomain: domain.title)
            reveal(row)
            XCTAssertTrue(row.isHittable)
        }
        capture("36_Seven_domains_archived")
        selectTab("总览")
    }

    @MainActor
    func testEnergyGestureSavesThreeMoodBandsAndValuesStayInRange() throws {
        launchFresh()
        selectTab("记录")
        let fixtures: [(domain: String, title: String, body: String, position: CGFloat, mood: String, range: ClosedRange<Int>)] = [
            ("career", "事业与创造", "Energy-low", 0.15, "淡漠", 1...33),
            ("finance", "财务与资源", "Energy-middle", 0.50, "平静", 34...66),
            ("body", "身体与精力", "Energy-high", 0.85, "冲动", 67...99)
        ]

        for (index, fixture) in fixtures.enumerated() {
            selectDomain(fixture.domain, title: fixture.title)
            enterRecord(fixture.body)
            let bar = identified("mood-energy-bar")
            reveal(bar)
            if index == 0 { capture("32_Energy_expanded") }
            dragEnergyBar(bar, to: fixture.position)
            let flame = identified("mood-flame-selection")
            XCTAssertTrue(flame.waitForExistence(timeout: 5))
            XCTAssertTrue(flame.label.contains(fixture.mood))
            if index == 0 { capture("33_Flame_saved") }
            saveRecord()
            XCTAssertTrue(app.buttons["wheel.domain.\(fixture.domain)"].label.contains("已记录"))
        }

        selectTab("对比")
        XCTAssertTrue(identified("comparison-view").waitForExistence(timeout: 5))
        capture("34_Comparison")
        for fixture in fixtures.reversed() {
            let row = comparisonRow(forDomain: fixture.title)
            reveal(row)
            let recordID = String(row.identifier.dropFirst("comparison.entry.".count))
            let rowLevel = identified("comparison.level.\(recordID)")
            let intensity = try intensityValue(in: rowLevel.exists ? rowLevel : row)
            XCTAssertTrue((1...99).contains(intensity))
            XCTAssertTrue(fixture.range.contains(intensity), "The archived intensity should match the released section of the energy bar.")
            XCTAssertTrue(row.label.contains(fixture.mood))
            row.tap()
            XCTAssertTrue(identified("comparison-detail").waitForExistence(timeout: 5))
            XCTAssertEqual(try intensityValue(in: identified("comparison.detail.level")), intensity)
            XCTAssertTrue(app.staticTexts[fixture.mood].exists)
            XCTAssertTrue(identified("comparison.content").label.contains(fixture.body))
            returnFromComparisonDetail()
        }
        selectTab("总览")
    }

    @MainActor
    func testEditedRecordsCreateSeparateReadonlySnapshotsWithoutDuplicateSave() {
        launchFresh()
        selectTab("记录")
        selectDomain("career", title: "事业与创造")
        enterRecord("Snapshot A")
        saveRecord()
        enterRecord("Snapshot B", replacing: true)
        saveRecord()
        // Saving unchanged content must not create a third historical snapshot.
        saveRecord()
        enterRecord("Uncommitted draft", replacing: true)

        selectTab("对比")
        XCTAssertTrue(identified("comparison-view").waitForExistence(timeout: 5))
        XCTAssertEqual(comparisonRows.count, 2)
        let newer = comparisonRows.element(boundBy: 0)
        let older = comparisonRows.element(boundBy: 1)
        XCTAssertNotEqual(newer.identifier, older.identifier)
        reveal(older)
        capture("37_Immutable_snapshots")
        older.tap()

        XCTAssertTrue(identified("comparison-detail").waitForExistence(timeout: 5))
        let content = identified("comparison.content")
        XCTAssertEqual(content.label, "Snapshot A")
        XCTAssertFalse(app.textViews["record-body"].exists)
        XCTAssertEqual(app.textFields.count, 0)
        XCTAssertFalse(app.buttons["journal.edit"].exists)
        XCTAssertFalse(app.buttons["编辑"].exists)
        capture("35_Readonly_detail")

        returnFromComparisonDetail()
        comparisonRows.element(boundBy: 0).tap()
        XCTAssertTrue(identified("comparison-detail").waitForExistence(timeout: 5))
        XCTAssertEqual(identified("comparison.content").label, "Snapshot B")
        selectTab("记录")
        XCTAssertTrue(recordInput.waitForExistence(timeout: 5))
        XCTAssertEqual(recordInput.value as? String, "Uncommitted draft")
        selectTab("总览")
    }

    @MainActor
    private var recordInput: XCUIElement { app.textViews["record-body"] }

    @MainActor
    private var comparisonRows: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "comparison.entry."))
    }

    @MainActor
    private func comparisonRow(forDomain title: String) -> XCUIElement {
        comparisonRows.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    @MainActor
    private func launchFresh() {
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset", "--uitesting-empty"]
        app.launch()
        XCTAssertTrue(identified("dashboard-view").waitForExistence(timeout: 10))
    }

    @MainActor
    private func identified(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func selectDomain(_ id: String, title: String) {
        dismissKeyboard()
        let wheel = identified("dimension-wheel")
        reveal(wheel, swipingUp: false)
        let sector = app.buttons["wheel.domain.\(id)"]
        XCTAssertTrue(sector.waitForExistence(timeout: 5))
        sector.tap()
        let heading = identified("record-domain-title")
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }

    @MainActor
    private func enterRecord(_ text: String, replacing: Bool = false) {
        reveal(recordInput)
        if replacing {
            let previous = recordInput.value as? String ?? ""
            recordInput.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.75)).tap()
            recordInput.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        } else {
            recordInput.tap()
        }
        recordInput.typeText(text)
        XCTAssertEqual(recordInput.value as? String, text)
        if text == "Snapshot A" { capture("39_Record_keyboard") }
        dismissKeyboard()
    }

    @MainActor
    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.buttons["完成"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
    }

    @MainActor
    private func dragEnergyBar(_ bar: XCUIElement, to position: CGFloat) {
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.7))
        let end = bar.coordinate(withNormalizedOffset: CGVector(dx: position, dy: 0.7))
        start.press(forDuration: 0.2, thenDragTo: end)
        waitUntilGone(bar)
    }

    @MainActor
    private func saveRecord() {
        dismissKeyboard()
        // A new record requires an explicit mood choice. Existing saved drafts already
        // contain a committed intensity and can be saved again without changing it.
        let bar = identified("mood-energy-bar")
        if bar.exists {
            reveal(bar)
            dragEnergyBar(bar, to: 0.5)
        }
        let save = app.buttons["record-save"]
        reveal(save)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(identified("record-saved").waitForExistence(timeout: 5))
    }

    @MainActor
    private func returnFromComparisonDetail() {
        app.navigationBars.firstMatch.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(identified("comparison-view").waitForExistence(timeout: 5))
    }

    @MainActor
    private func intensityValue(in element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) throws -> Int {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        var candidates = [element.label]
        if let value = element.value as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates.append(value)
        }
        // SwiftUI may expose a row's child Text with an empty value or label even
        // though the NavigationLink's combined label contains the visible intensity.
        let levelPrefix = "comparison.level."
        if element.identifier.hasPrefix(levelPrefix) {
            let recordID = String(element.identifier.dropFirst(levelPrefix.count))
            let row = app.buttons["comparison.entry.\(recordID)"]
            if row.exists { candidates.insert(row.label, at: 0) }
        }
        let text = candidates.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        let values = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return try XCTUnwrap(values.first, "Intensity must expose a numeric accessibility value or label. Received: \(text)", file: file, line: line)
    }

    /// Handles both conventional UITabBar descendants and iOS floating tab bar buttons.
    @MainActor
    private func selectTab(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        dismissKeyboard()
        let tabBarButton = app.tabBars.buttons[label].firstMatch
        let fallbackButton = app.buttons[label].firstMatch
        for _ in 0..<4 {
            let button = tabBarButton.exists ? tabBarButton : fallbackButton
            if button.exists && button.isHittable {
                button.tap()
                return
            }
            app.swipeDown()
        }
        XCTFail("Could not reach the \(label) tab.", file: file, line: line)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, maxSwipes: Int = 9, swipingUp: Bool = true,
                        file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0...maxSwipes {
            if element.exists && element.isHittable { return }
            let scrollView = app.scrollViews.firstMatch
            let surface = scrollView.exists ? scrollView : app!
            // The edge avoids dragging the central wheel or the mood control.
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: swipingUp ? 0.77 : 0.28))
            let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: swipingUp ? 0.28 : 0.77))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture("Unable_to_reveal_element")
        XCTFail("The expected element did not become visible: \(element)", file: file, line: line)
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, file: file, line: line)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

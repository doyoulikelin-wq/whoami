import Foundation
import XCTest
@testable import WhoAmI

@MainActor
final class IndependentRecordTests: XCTestCase {
    func testSavingCreatesOneTimestampedEntryAndClearsOnlyItsDraftAcrossRestart() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let otherDraft = DimensionDraft(body: "另一维度还没有保存", intensity: 29,
                                            hasChosenIntensity: true)
            store.setDimensionDraft(otherDraft, for: .finance)
            store.setDimensionDraft(DimensionDraft(body: "今天早上的事情", intensity: 74,
                                                   hasChosenIntensity: true), for: .career)
            let time = Date(timeIntervalSince1970: 1_788_800_123.125)

            let entry = try XCTUnwrap(store.saveDimension(.career, at: time))
            XCTAssertEqual(entry.createdAt, time)
            XCTAssertEqual(entry.updatedAt, time)
            XCTAssertEqual(entry.body, "今天早上的事情")
            XCTAssertEqual(entry.domain, .career)
            XCTAssertEqual(entry.moodIntensity, 74)
            XCTAssertEqual(store.entries, [entry])
            XCTAssertEqual(store.dimensionDraft(for: .career), DimensionDraft())
            XCTAssertEqual(store.dimensionDraft(for: .finance), otherDraft)

            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertNil(restarted.storageError)
            XCTAssertEqual(restarted.entries, [entry])
            XCTAssertEqual(restarted.dimensionDraft(for: .career), DimensionDraft())
            XCTAssertEqual(restarted.dimensionDraft(for: .finance), otherDraft)
        }
    }

    func testIdenticalTextAndMoodEnteredAgainCreateIndependentIDsAndTimes() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let draft = DimensionDraft(body: "完成了一轮练习", intensity: 50, hasChosenIntensity: true)
            let firstTime = Date(timeIntervalSince1970: 1_788_800_100.25)
            let secondTime = firstTime.addingTimeInterval(3_600.5)
            store.setDimensionDraft(draft, for: .learning)
            let first = try XCTUnwrap(store.saveDimension(.learning, at: firstTime))
            store.setDimensionDraft(draft, for: .learning)
            let second = try XCTUnwrap(store.saveDimension(.learning, at: secondTime))

            XCTAssertNotEqual(first.id, second.id)
            XCTAssertEqual(first.createdAt, firstTime)
            XCTAssertEqual(second.createdAt, secondTime)
            XCTAssertEqual(first.body, second.body)
            XCTAssertEqual(first.moodIntensity, second.moodIntensity)
            XCTAssertEqual(store.entries, [first, second])
            XCTAssertEqual(store.entry(first.id), first)
            XCTAssertEqual(AppStore(fileURL: url, arguments: []).entries, [first, second])
        }
    }

    func testRepeatedSaveWithoutNewInputCannotDuplicateThePreviousEntry() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            store.setDimensionDraft(DimensionDraft(body: "只提交一次", intensity: 88,
                                                   hasChosenIntensity: true), for: .emotion)
            let saved = try XCTUnwrap(store.saveDimension(.emotion))
            for _ in 0..<3 { XCTAssertNil(store.saveDimension(.emotion)) }
            XCTAssertEqual(store.entries, [saved])

            store.setDimensionDraft(DimensionDraft(body: " \n\t ", intensity: 88,
                                                   hasChosenIntensity: true), for: .emotion)
            XCTAssertNil(store.saveDimension(.emotion))
            XCTAssertEqual(store.entries, [saved])

            store.setDimensionDraft(DimensionDraft(body: "新事情，尚未选择心境"), for: .emotion)
            XCTAssertNil(store.saveDimension(.emotion))
            XCTAssertEqual(store.dimensionDraft(for: .emotion).body, "新事情，尚未选择心境")
            XCTAssertEqual(store.entries, [saved])
        }
    }

    func testArchivedRecordsNeverAutomaticallyFillAnEmptyDimension() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let historical = record("昨天的内容", domain: .body, level: 63,
                                    at: Date(timeIntervalSince1970: 1_788_700_000))
            store.entries = [historical]
            XCTAssertEqual(store.latestRecord(for: .body), historical)
            XCTAssertEqual(store.dimensionDraft(for: .body), DimensionDraft())
            XCTAssertEqual(AppStore(fileURL: url, arguments: []).dimensionDraft(for: .body),
                           DimensionDraft())
        }
    }

    func testWheelUsesLatestRealEntryOfEachDimensionOnTheRequestedLocalDay() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let calendar = makeCalendar("Asia/Shanghai")
            let start = try localDate(2026, 9, 8, calendar: calendar)
            let yesterday = start.addingTimeInterval(-1)
            let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
            var demo = record("示例不能点亮", domain: .emotion, level: 99,
                              at: start.addingTimeInterval(3_000))
            demo.isDemo = true
            // Deliberately unsorted: array position must not decide which flame wins.
            store.entries = [
                record("后一次事业记录", domain: .career, level: 82, at: start.addingTimeInterval(7_200)),
                record("昨日身体记录", domain: .body, level: 44, at: yesterday),
                record("当日财务记录", domain: .finance, level: 28, at: start.addingTimeInterval(1)),
                record("明日学习记录", domain: .learning, level: 77, at: tomorrow),
                record("前一次事业记录", domain: .career, level: 15, at: start),
                demo
            ]

            XCTAssertEqual(store.savedDimensionLevels(on: start.addingTimeInterval(43_200), calendar: calendar),
                           [.career: 82, .finance: 28])
            XCTAssertEqual(store.savedDimensionLevels(on: yesterday, calendar: calendar), [.body: 44])
            XCTAssertEqual(store.savedDimensionLevels(on: tomorrow, calendar: calendar), [.learning: 77])
            XCTAssertEqual(store.entries.count, 6, "Daily wheel filtering must not delete history")
        }
    }

    func testWheelResetsAtLocalMidnightRatherThanAfterTwentyFourHours() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let calendar = makeCalendar("Asia/Shanghai")
            let midnight = try localDate(2026, 9, 9, calendar: calendar)
            store.entries = [
                record("午夜之前", domain: .career, level: 33, at: midnight.addingTimeInterval(-0.25)),
                record("午夜之后", domain: .finance, level: 67, at: midnight)
            ]

            XCTAssertEqual(store.savedDimensionLevels(on: midnight.addingTimeInterval(-0.001), calendar: calendar),
                           [.career: 33])
            XCTAssertEqual(store.savedDimensionLevels(on: midnight, calendar: calendar), [.finance: 67])
            XCTAssertEqual(store.entries.count, 2)
        }
    }

    func testWheelIncludesCompleteSpringAndAutumnDaylightSavingDays() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let calendar = makeCalendar("America/Los_Angeles")
            for (month, day, hours) in [(3, 8, 23.0), (11, 1, 25.0)] {
                let start = try localDate(2026, month, day, calendar: calendar)
                let interval = try XCTUnwrap(calendar.dateInterval(of: .day, for: start))
                XCTAssertEqual(interval.duration, hours * 3_600)
                store.entries = [
                    record("上个当地日", domain: .career, level: 10, at: interval.start.addingTimeInterval(-1)),
                    record("当天起点", domain: .finance, level: 34, at: interval.start),
                    record("当天最后一刻", domain: .body, level: 66, at: interval.end.addingTimeInterval(-0.001)),
                    record("下个当地日", domain: .emotion, level: 90, at: interval.end)
                ]

                XCTAssertEqual(store.savedDimensionLevels(on: interval.start.addingTimeInterval(3_600), calendar: calendar),
                               [.finance: 34, .body: 66], "Incorrect local-day boundaries for \(month)/\(day)")
                XCTAssertEqual(store.savedDimensionLevels(on: interval.end, calendar: calendar), [.emotion: 90])
            }
        }
    }

    func testLegacyMigrationClearsOnlyAnExactChosenCopyOfTheLatestSavedRecord() throws {
        try withTemporaryStoreURL { url in
            let time = Date(timeIntervalSince1970: 1_788_800_000.125)
            let entries = [
                record("已保存事业", domain: .career, level: 73, at: time),
                record("财务文字相同", domain: .finance, level: 34, at: time),
                record("身体原内容", domain: .body, level: 55, at: time),
                record("尚未选择心境", domain: .emotion, level: 50, at: time),
                record("学习旧内容", domain: .learning, level: 83, at: time),
                record("学习最新内容", domain: .learning, level: 83, at: time.addingTimeInterval(1)),
                record("关系内容", domain: .relationships, level: 18, at: time),
                record("历史不能回填", domain: .life, level: 60, at: time)
            ]
            let drafts: [String: DimensionDraft] = [
                LifeDomain.career.rawValue: DimensionDraft(body: "已保存事业", intensity: 73, hasChosenIntensity: true),
                LifeDomain.finance.rawValue: DimensionDraft(body: "财务文字相同", intensity: 35, hasChosenIntensity: true),
                LifeDomain.body.rawValue: DimensionDraft(body: "身体改写，还未保存", intensity: 55, hasChosenIntensity: true),
                LifeDomain.emotion.rawValue: DimensionDraft(body: "尚未选择心境", intensity: 50, hasChosenIntensity: false),
                LifeDomain.learning.rawValue: DimensionDraft(body: "学习旧内容", intensity: 83, hasChosenIntensity: true),
                LifeDomain.relationships.rawValue: DimensionDraft(body: " 关系内容\n", intensity: 18, hasChosenIntensity: true)
            ]
            let fixture = LegacySnapshot(entries: entries, dimensionDrafts: drafts)
            let original = try JSONEncoder().encode(fixture)
            try original.write(to: url)

            let store = AppStore(fileURL: url, arguments: [])
            XCTAssertNil(store.storageError)
            XCTAssertEqual(store.entries, entries)
            XCTAssertEqual(store.dimensionDraft(for: .career), DimensionDraft())
            for domain in LifeDomain.allCases where domain != .career && domain != .life {
                XCTAssertEqual(store.dimensionDraft(for: domain), drafts[domain.rawValue],
                               "Migration removed unfinished \(domain.rawValue) input")
            }
            XCTAssertEqual(store.dimensionDraft(for: .life), DimensionDraft())
            XCTAssertEqual(store.draftText, fixture.draftText)
            XCTAssertEqual(store.draftDomain, fixture.draftDomain)
            XCTAssertEqual(store.recordingDomain, fixture.recordingDomain)

            let before = try jsonObject(original)
            let after = try jsonObject(Data(contentsOf: url))
            XCTAssertEqual(after["recordingModeVersion"] as? Int, 1)
            for key in before.keys where key != "dimensionDrafts" && key != "recordingModeVersion" {
                XCTAssertEqual(try canonicalJSON(before[key]), try canonicalJSON(after[key]),
                               "Migration changed unrelated field \(key)")
            }
            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(restarted.entries, entries)
            XCTAssertEqual(restarted.dimensionDrafts, store.dimensionDrafts)
            XCTAssertEqual(restarted.draftText, fixture.draftText)
        }
    }

    func testVersionZeroAlsoMigratesTheOldSavedRecordCache() throws {
        try withTemporaryStoreURL { url in
            let entry = record("旧版回填", domain: .career, level: 20, at: .now)
            var fixture = LegacySnapshot(entries: [entry], dimensionDrafts: [
                LifeDomain.career.rawValue: DimensionDraft(body: entry.body, intensity: 20, hasChosenIntensity: true)
            ])
            fixture.recordingModeVersion = 0
            try JSONEncoder().encode(fixture).write(to: url)

            let store = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(store.dimensionDraft(for: .career), DimensionDraft())
            XCTAssertEqual(store.entries, [entry])
            XCTAssertEqual(try jsonObject(Data(contentsOf: url))["recordingModeVersion"] as? Int, 1)
        }
    }

    func testNewModePreservesUnsubmittedInputEvenWhenItMatchesHistoricalContent() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let draft = DimensionDraft(body: "再一次发生同样的事情", intensity: 49, hasChosenIntensity: true)
            store.setDimensionDraft(draft, for: .relationships)
            let first = try XCTUnwrap(store.saveDimension(.relationships))
            store.setDimensionDraft(draft, for: .relationships)

            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(restarted.dimensionDraft(for: .relationships), draft)
            XCTAssertEqual(restarted.entries, [first])
            let secondRestart = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(secondRestart.dimensionDraft(for: .relationships), draft)
            XCTAssertEqual(secondRestart.entries, [first])
            let second = try XCTUnwrap(secondRestart.saveDimension(.relationships,
                                      at: first.createdAt.addingTimeInterval(60)))
            XCTAssertNotEqual(second.id, first.id)
            XCTAssertEqual(secondRestart.entries, [first, second])
        }
    }

    func testFailedSaveKeepsAllInputAndHistoryAndCanBeRetried() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let originalEntry = record("既有档案", domain: .career, level: 10,
                                       at: Date(timeIntervalSince1970: 1_788_700_000))
            store.entries = [originalEntry]
            let pending = DimensionDraft(body: "本次还没有成功保存", intensity: 91, hasChosenIntensity: true)
            store.setDimensionDraft(pending, for: .career)
            store.setDimensionDraft(DimensionDraft(body: "另一份未提交草稿"), for: .life)
            let previousDrafts = store.dimensionDrafts
            let preservedURL = url.deletingLastPathComponent().appendingPathComponent("original.json")
            try FileManager.default.moveItem(at: url, to: preservedURL)
            let originalBytes = try Data(contentsOf: preservedURL)
            // A nonempty directory gives a deterministic failure even when running with broad filesystem access.
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            let markerURL = url.appendingPathComponent("retain.txt")
            let marker = Data("Existing path content".utf8)
            try marker.write(to: markerURL)
            let time = Date(timeIntervalSince1970: 1_788_800_000.5)

            XCTAssertNil(store.saveDimension(.career, at: time))
            XCTAssertNotNil(store.storageError)
            XCTAssertEqual(store.entries, [originalEntry])
            XCTAssertEqual(store.dimensionDrafts, previousDrafts)
            XCTAssertEqual(store.dimensionDraft(for: .career), pending)
            XCTAssertEqual(try Data(contentsOf: preservedURL), originalBytes)
            XCTAssertEqual(try Data(contentsOf: markerURL), marker)

            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: preservedURL, to: url)
            let recovered = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(recovered.entries, [originalEntry])
            XCTAssertEqual(recovered.dimensionDrafts, previousDrafts)
            let saved = try XCTUnwrap(store.saveDimension(.career, at: time))
            XCTAssertNil(store.storageError)
            XCTAssertEqual(store.entries, [originalEntry, saved])
            XCTAssertEqual(store.dimensionDraft(for: .career), DimensionDraft())
            XCTAssertEqual(store.dimensionDraft(for: .life), previousDrafts[LifeDomain.life.rawValue])
        }
    }

    private func withTemporaryStoreURL(_ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhoAmI-independent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory.appendingPathComponent("whoami-v1.json"))
    }

    private func record(_ body: String, domain: LifeDomain, level: Int, at date: Date) -> JournalEntry {
        JournalEntry(title: body, body: body, createdAt: date, domain: domain,
                     mood: nil, moodIntensity: level, updatedAt: date)
    }

    private func makeCalendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func localDate(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func canonicalJSON(_ value: Any?) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["value": try XCTUnwrap(value)], options: [.sortedKeys])
    }

    private struct LegacySnapshot: Codable {
        var entries: [JournalEntry]
        var projects: [GrowthProject] = []
        var questions: [OpenQuestion] = []
        var reviews: [ReviewReport] = []
        var mood: Mood? = .tired
        var energy = 2
        var reviewInterval = 4
        var focus = "  保留旧版关注点\n"
        var draftText = "  旧编辑器未提交文本\n"
        var draftDomain: LifeDomain? = .finance
        var draftMood: Mood? = .focused
        var draftProjectID: UUID? = UUID()
        var dimensionDrafts: [String: DimensionDraft]
        var recordingDomain: LifeDomain = .learning
        var recordingModeVersion: Int? = nil
    }
}

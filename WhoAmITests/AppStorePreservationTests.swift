import Foundation
import XCTest
@testable import WhoAmI

@MainActor
final class AppStorePreservationTests: XCTestCase {
    func testUpgradeRemovesOnlyExamplesAndPreservesEveryRealFieldAcrossRestart() throws {
        try withTemporaryStoreURL { url in
            let fixture = makeLegacyFixture()
            let original = try JSONEncoder().encode(fixture)
            try original.write(to: url)

            let store = AppStore(fileURL: url, arguments: [])
            XCTAssertNil(store.storageError)
            XCTAssertEqual(store.entries, fixture.entries.filter { !$0.isDemo })
            XCTAssertEqual(store.dimensionDrafts, fixture.dimensionDrafts)
            XCTAssertEqual(store.recordingDomain, fixture.recordingDomain)
            XCTAssertEqual(store.draftText, fixture.draftText)
            XCTAssertEqual(store.draftDomain, fixture.draftDomain)
            XCTAssertEqual(store.draftMood, fixture.draftMood)
            XCTAssertEqual(store.draftProjectID, fixture.draftProjectID)
            XCTAssertFalse(store.hasExamples)

            // Compare the complete persisted document, including legacy fields and
            // references to removed examples. No real field should be rewritten.
            var expected = try jsonObject(original)
            for key in ["entries", "projects", "questions", "reviews"] {
                let values = try XCTUnwrap(expected[key] as? [[String: Any]])
                expected[key] = values.filter { ($0["isDemo"] as? Bool) != true }
            }
            expected["recordingModeVersion"] = 1
            let migrated = try jsonObject(Data(contentsOf: url))
            XCTAssertEqual(migrated as NSDictionary, expected as NSDictionary)

            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertNil(restarted.storageError)
            XCTAssertEqual(restarted.entries, store.entries)
            XCTAssertEqual(restarted.dimensionDrafts, fixture.dimensionDrafts)
            XCTAssertEqual(try jsonObject(Data(contentsOf: url)) as NSDictionary,
                           expected as NSDictionary)
        }
    }

    func testNewInstallationAndRestartContainNoExamples() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            XCTAssertNil(store.storageError)
            XCTAssertTrue(store.entries.isEmpty)
            XCTAssertTrue(store.projects.isEmpty)
            XCTAssertTrue(store.questions.isEmpty)
            XCTAssertTrue(store.reviews.isEmpty)
            XCTAssertTrue(store.dimensionDrafts.isEmpty)
            XCTAssertFalse(store.hasExamples)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertTrue(restarted.entries.isEmpty)
            XCTAssertTrue(restarted.projects.isEmpty)
            XCTAssertTrue(restarted.questions.isEmpty)
            XCTAssertTrue(restarted.reviews.isEmpty)
            XCTAssertFalse(restarted.hasExamples)
        }
    }

    func testImportDeduplicatesUUIDsWithoutReplacingLocalOrEarlierImportedContent() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let local = makeRecord(body: "Local original", domain: .career, timestamp: 123.125)
            store.entries = [local]
            var conflictingLocal = local
            conflictingLocal.body = "An imported file must not overwrite this UUID"
            conflictingLocal.createdAt = Date(timeIntervalSince1970: 999)

            let imported = makeRecord(body: "First incoming version", domain: .finance, timestamp: 456.875)
            var repeatedIncoming = imported
            repeatedIncoming.body = "Later duplicate within the same import"
            let result = try store.importRecords([conflictingLocal, imported, repeatedIncoming])
            XCTAssertEqual(result.added, 1)
            XCTAssertEqual(result.skipped, 2)
            XCTAssertEqual(store.entries.count, 2)
            XCTAssertEqual(store.entry(local.id), local)
            XCTAssertEqual(store.entry(imported.id), imported)

            let repeatedResult = try store.importRecords([imported, conflictingLocal])
            XCTAssertEqual(repeatedResult.added, 0)
            XCTAssertEqual(repeatedResult.skipped, 2)
            XCTAssertEqual(store.entries.count, 2)
            XCTAssertEqual(store.entry(local.id), local)
            XCTAssertEqual(store.entry(imported.id), imported)

            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(restarted.entries, store.entries)
            XCTAssertEqual(restarted.entry(local.id), local)
        }
    }

    func testImportRetainsPreciseTimestampsAndAllUnfinishedDrafts() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let drafts = makeDimensionDrafts()
            store.dimensionDrafts = drafts
            store.recordingDomain = .relationships
            store.draftText = "  未保存的旧草稿\n保留末尾空白  \n"
            store.draftDomain = .body
            store.draftMood = .tired
            let projectID = UUID()
            store.draftProjectID = projectID
            let before = try jsonObject(Data(contentsOf: url))
            let record = makeRecord(body: "  Imported verbatim\n第二段  ", domain: .emotion,
                                    timestamp: 1_788_800_123.125)

            let result = try store.importRecords([record])
            XCTAssertEqual(result.added, 1)
            XCTAssertEqual(result.skipped, 0)
            XCTAssertEqual(store.entry(record.id), record)
            XCTAssertEqual(store.entry(record.id)?.createdAt.timeIntervalSince1970,
                           record.createdAt.timeIntervalSince1970)
            XCTAssertEqual(store.entry(record.id)?.updatedAt, record.updatedAt)
            XCTAssertEqual(store.dimensionDrafts, drafts)
            XCTAssertEqual(store.recordingDomain, .relationships)
            XCTAssertEqual(store.draftProjectID, projectID)
            let after = try jsonObject(Data(contentsOf: url))
            for key in before.keys where key != "entries" {
                XCTAssertEqual(try canonicalJSON(before[key]), try canonicalJSON(after[key]),
                               "Import changed unrelated store field: \(key)")
            }

            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(restarted.entry(record.id), record)
            XCTAssertEqual(restarted.dimensionDrafts, drafts)
            XCTAssertEqual(restarted.draftText, store.draftText)
            XCTAssertEqual(restarted.draftDomain, store.draftDomain)
            XCTAssertEqual(restarted.draftMood, store.draftMood)
            XCTAssertEqual(restarted.draftProjectID, projectID)
            XCTAssertEqual(restarted.recordingDomain, .relationships)
        }
    }

    func testFailedImportWriteDoesNotPublishChangesOrReplaceExistingPathContents() throws {
        try withTemporaryStoreURL { url in
            let store = AppStore(fileURL: url, arguments: [])
            let existing = makeRecord(body: "Keep local record", domain: .learning, timestamp: 1_000)
            store.entries = [existing]
            store.dimensionDrafts = makeDimensionDrafts()
            store.draftText = "Still editing"
            let previousEntries = store.entries
            let previousDrafts = store.dimensionDrafts
            let preservedFile = url.deletingLastPathComponent().appendingPathComponent("original.json")
            try FileManager.default.moveItem(at: url, to: preservedFile)
            let originalBytes = try Data(contentsOf: preservedFile)

            // Writing JSON over a nonempty directory fails independently of the
            // test process's filesystem permissions.
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            let markerURL = url.appendingPathComponent("do-not-overwrite.txt")
            let marker = Data("existing path contents".utf8)
            try marker.write(to: markerURL)
            let incoming = makeRecord(body: "Should never be published", domain: .life, timestamp: 2_000)

            XCTAssertThrowsError(try store.importRecords([incoming]))
            XCTAssertEqual(store.entries, previousEntries)
            XCTAssertNil(store.entry(incoming.id))
            XCTAssertEqual(store.dimensionDrafts, previousDrafts)
            XCTAssertEqual(store.draftText, "Still editing")
            XCTAssertEqual(try Data(contentsOf: markerURL), marker)
            XCTAssertEqual(try Data(contentsOf: preservedFile), originalBytes)

            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: preservedFile, to: url)
            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertEqual(restarted.entries, previousEntries)
            XCTAssertEqual(restarted.dimensionDrafts, previousDrafts)
        }
    }

    func testUnreadableSnapshotRejectsImportAndPreservesOriginalBytes() throws {
        try withTemporaryStoreURL { url in
            let corrupt = Data("{\"entries\":[\"unfinished original content\"".utf8)
            try corrupt.write(to: url)
            let store = AppStore(fileURL: url, arguments: [])
            XCTAssertNotNil(store.storageError)
            XCTAssertEqual(try Data(contentsOf: url), corrupt)

            let incoming = makeRecord(body: "Must not replace damaged storage", domain: .career, timestamp: 3_000)
            XCTAssertThrowsError(try store.importRecords([incoming]))
            XCTAssertTrue(store.entries.isEmpty)
            XCTAssertEqual(try Data(contentsOf: url), corrupt)

            let restarted = AppStore(fileURL: url, arguments: [])
            XCTAssertNotNil(restarted.storageError)
            XCTAssertTrue(restarted.entries.isEmpty)
            XCTAssertEqual(try Data(contentsOf: url), corrupt)
        }
    }

    private func withTemporaryStoreURL(_ operation: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhoAmI-preservation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try operation(directory.appendingPathComponent("whoami-v1.json"))
    }

    private func makeRecord(body: String, domain: LifeDomain, timestamp: TimeInterval) -> JournalEntry {
        JournalEntry(title: "虚构测试标题", body: body,
                     createdAt: Date(timeIntervalSince1970: timestamp), domain: domain,
                     mood: .focused, projectID: UUID(), moodIntensity: 73,
                     updatedAt: Date(timeIntervalSince1970: timestamp + 1.375))
    }

    private func makeDimensionDrafts() -> [String: DimensionDraft] {
        Dictionary(uniqueKeysWithValues: LifeDomain.allCases.enumerated().map { index, domain in
            (domain.rawValue, DimensionDraft(body: "  \(domain.title)未保存\n\t尾部  ",
                                             intensity: index * 13 + 1,
                                             hasChosenIntensity: index.isMultiple(of: 2)))
        })
    }

    private func makeLegacyFixture() -> LegacySnapshot {
        let demoProject = GrowthProject(title: "示例项目", summary: "虚构示例", domain: .career,
                                        progress: 0.25, nextStep: "示例下一步", isDemo: true)
        let realProject = GrowthProject(title: "真实字段测试项目", summary: "  原始摘要\n",
                                        domain: .learning, progress: 0.625, nextStep: "保留下一步")
        var real = makeRecord(body: "  当日自写内容\n第二行：`code` 与中文。  \n",
                              domain: .career, timestamp: 1_788_800_123.125)
        real.projectID = demoProject.id
        var demo = makeRecord(body: "仅此示例可被清理", domain: .finance, timestamp: 1_788_700_000)
        demo.isDemo = true
        let realQuestion = OpenQuestion(title: "保留问题", note: " 原始笔记\n")
        let demoQuestion = OpenQuestion(title: "示例问题", note: "虚构", isDemo: true)
        let realReview = ReviewReport(createdAt: real.createdAt, periodStart: demo.createdAt,
                                      periodEnd: real.updatedAt!, entryIDs: [real.id, demo.id],
                                      summary: "原始复盘", observation: "观察", hypothesis: "待核对",
                                      action: "保留行动", feedback: "  未裁剪反馈\n", actionDone: true)
        let demoReview = ReviewReport(createdAt: demo.createdAt, periodStart: demo.createdAt,
                                      periodEnd: real.createdAt, entryIDs: [demo.id], summary: "示例复盘",
                                      observation: "虚构", hypothesis: "虚构", action: "虚构", isDemo: true)
        return LegacySnapshot(entries: [demo, real], projects: [realProject, demoProject],
                              questions: [demoQuestion, realQuestion], reviews: [realReview, demoReview],
                              mood: .low, energy: 2, reviewInterval: 4, focus: "  自定义关注点\n",
                              draftText: "  旧版未提交草稿\n不可丢失  ", draftDomain: .body,
                              draftMood: .tired, draftProjectID: demoProject.id,
                              dimensionDrafts: makeDimensionDrafts(), recordingDomain: .relationships)
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func canonicalJSON(_ value: Any?) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["value": try XCTUnwrap(value)], options: [.sortedKeys])
    }

    private struct LegacySnapshot: Codable {
        var entries: [JournalEntry]
        var projects: [GrowthProject]
        var questions: [OpenQuestion]
        var reviews: [ReviewReport]
        var mood: Mood?
        var energy: Int
        var reviewInterval: Int
        var focus: String
        var draftText: String
        var draftDomain: LifeDomain?
        var draftMood: Mood?
        var draftProjectID: UUID?
        var dimensionDrafts: [String: DimensionDraft]
        var recordingDomain: LifeDomain
    }
}

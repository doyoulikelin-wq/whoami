import XCTest
@testable import WhoAmI

final class RecordArchiveTests: XCTestCase {
    private let zone = TimeZone(identifier: "Asia/Shanghai")!
    private let exportedAt = Date(timeIntervalSince1970: 1_788_750_306.789)

    private func entry(body: String = "实际完成一项任务。", date: Date? = nil,
                       domain: LifeDomain? = .career, intensity: Int? = 51,
                       isDemo: Bool = false) -> JournalEntry {
        JournalEntry(title: "原始标题", body: body, createdAt: date ?? exportedAt,
            domain: domain, mood: .focused, projectID: UUID(), isDemo: isDemo,
            moodIntensity: intensity, updatedAt: date ?? exportedAt)
    }

    private func archive(_ entries: [JournalEntry], scope: RecordArchive.Scope = .all,
                         format: RecordArchive.Format = .json) throws -> Data {
        try RecordArchive.data(entries: entries, scope: scope, format: format,
            timeZone: zone, exportedAt: exportedAt)
    }

    private func mutatedArchive(_ mutate: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: archive([entry()])) as? [String: Any])
        mutate(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func mutatedRecord(_ mutate: (inout [String: Any]) -> Void) throws -> Data {
        try mutatedArchive { object in
            var records = object["records"] as! [[String: Any]]
            mutate(&records[0])
            object["records"] = records
        }
    }

    func testJSONRoundTripPreservesOriginalTextMetadataAndMillisecondTimestamps() throws {
        let body = "  中文 🧭\n\n# 标题\n```swift\nlet x = \"边界\"\n```\n\\路径\t尾部空格  \n"
        let original = entry(body: body)
        let data = try archive([original])
        let restored = try XCTUnwrap(RecordArchive.importEntries(from: data).first)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.title, original.title)
        XCTAssertEqual(restored.body, body)
        XCTAssertEqual(restored.domain, original.domain)
        XCTAssertEqual(restored.mood, original.mood)
        XCTAssertEqual(restored.moodIntensity, original.moodIntensity)
        XCTAssertEqual(restored.projectID, original.projectID)
        XCTAssertEqual(restored.createdAt.timeIntervalSince1970, original.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(restored.updatedAt).timeIntervalSince1970,
                       try XCTUnwrap(original.updatedAt).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertFalse(restored.isDemo)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["format"] as? String, "whoami.records")
        XCTAssertEqual(object["timeZone"] as? String, "Asia/Shanghai")
        let records = try XCTUnwrap(object["records"] as? [[String: Any]])
        let timestamp = try XCTUnwrap(records[0]["createdAt"] as? String)
        XCTAssertTrue(timestamp.hasSuffix(".789+08:00"), timestamp)
    }

    func testMissingHistoricalMoodAndDimensionRemainMissing() throws {
        var original = entry(domain: nil, intensity: nil)
        original.mood = nil
        original.projectID = nil
        original.updatedAt = nil
        let data = try archive([original])
        let restored = try XCTUnwrap(RecordArchive.importEntries(from: data).first)
        XCTAssertNil(restored.moodIntensity)
        XCTAssertNil(restored.domain)
        XCTAssertNil(restored.mood)
        XCTAssertNil(restored.projectID)
        XCTAssertNil(restored.updatedAt)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let records = try XCTUnwrap(object["records"] as? [[String: Any]])
        XCTAssertTrue(records[0]["moodIntensity"] is NSNull)
        XCTAssertTrue(records[0]["moodBand"] is NSNull)
        XCTAssertTrue(records[0]["domain"] is NSNull)
    }

    func testMarkdownKeepsUnicodeWhitespaceAndEmbeddedFencesInOneBodyBlock() throws {
        let body = "  第一行\n```json\n{\"任意内容\":true}\n```\n````\n最后一行  \n"
        let text = try XCTUnwrap(String(data: archive([entry(body: body)], format: .markdown), encoding: .utf8))
        XCTAssertTrue(text.contains("`````text\n" + body + "`````"))
        XCTAssertTrue(text.contains("- 记录时间："))
        XCTAssertTrue(text.contains("+08:00"))
        XCTAssertTrue(text.contains("- 维度：事业与创造（career）"))
        XCTAssertTrue(text.contains("- 心境：51 / 平静"))
        XCTAssertTrue(text.contains("## 记录 001"))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: Data(text.utf8)))
    }

    func testDayScopeUsesLocalMidnightAndExcludesNextMidnightAndExamples() throws {
        let formatter = ISO8601DateFormatter()
        let midnight = try XCTUnwrap(formatter.date(from: "2026-09-07T00:00:00+08:00"))
        let before = entry(date: midnight.addingTimeInterval(-0.001))
        let first = entry(date: midnight)
        let last = entry(date: midnight.addingTimeInterval(86_399.999))
        let next = entry(date: midnight.addingTimeInterval(86_400))
        let demo = entry(date: midnight.addingTimeInterval(100), isDemo: true)
        let restored = try RecordArchive.importEntries(from: archive([next, last, demo, before, first], scope: .day(midnight)))
        XCTAssertEqual(restored.map(\.id), [first.id, last.id])
        let all = try RecordArchive.importEntries(from: archive([next, last, demo, before, first]))
        XCTAssertEqual(all.map(\.id), [before.id, first.id, last.id, next.id])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: archive([first], scope: .day(midnight))) as? [String: Any])
        let scope = try XCTUnwrap(object["scope"] as? [String: Any])
        XCTAssertEqual(scope["date"] as? String, "2026-09-07")
    }

    func testDayScopeRespectsDaylightSavingBoundaries() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let formatter = ISO8601DateFormatter()
        let start = try XCTUnwrap(formatter.date(from: "2026-03-08T00:00:00-05:00"))
        let next = try XCTUnwrap(formatter.date(from: "2026-03-09T00:00:00-04:00"))
        let last = entry(date: next.addingTimeInterval(-1))
        let outside = entry(date: next)
        let data = try RecordArchive.data(entries: [outside, last], scope: .day(start), format: .json,
                                          timeZone: timeZone, exportedAt: exportedAt)
        XCTAssertEqual(try RecordArchive.importEntries(from: data).map(\.id), [last.id])
    }

    func testSubmillisecondTimestampBeforeMidnightDoesNotMoveToNextDay() throws {
        let formatter = ISO8601DateFormatter()
        let midnight = try XCTUnwrap(formatter.date(from: "2026-09-08T00:00:00+08:00"))
        let original = entry(date: midnight.addingTimeInterval(-0.0002))
        let data = try archive([original], scope: .day(original.createdAt))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let records = try XCTUnwrap(object["records"] as? [[String: Any]])
        XCTAssertEqual(records[0]["createdAt"] as? String, "2026-09-07T23:59:59.999+08:00")
        let scope = try XCTUnwrap(object["scope"] as? [String: Any])
        XCTAssertEqual(scope["date"] as? String, "2026-09-07")
        let restored = try XCTUnwrap(RecordArchive.importEntries(from: data).first)
        XCTAssertLessThan(restored.createdAt, midnight)
        XCTAssertEqual(restored.id, original.id)
    }

    func testRejectsUnsupportedSchemaAndForeignFormat() throws {
        for version in [2, true, "1"] as [Any] {
            let data = try mutatedArchive { $0["schemaVersion"] = version }
            XCTAssertThrowsError(try RecordArchive.importEntries(from: data))
        }
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedArchive { $0["format"] = "other-app" }))
    }

    func testRejectsInvalidDateMissingOffsetAndDateScopeMismatch() throws {
        for timestamp in ["2026-02-30T14:00:00.000+08:00", "2026-09-07", "2026-09-07T14:00:00.000", "2026-09-07T25:00:00.000+08:00", "2026-09-07T14:00:00.000+99:99"] {
            let data = try mutatedRecord { $0["createdAt"] = timestamp }
            XCTAssertThrowsError(try RecordArchive.importEntries(from: data), timestamp)
        }
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedArchive {
            $0["scope"] = ["kind": "day", "date": "2000-01-01"]
        }))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord { $0["updatedAt"] = "2000-01-01T00:00:00.000Z" }))
    }

    func testRejectsMoodOutsideRangeAndMismatchedBand() throws {
        for value in [0, 100, -1] {
            XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord { $0["moodIntensity"] = value }))
        }
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord { $0["moodIntensity"] = 1.5 }))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord { $0["moodBand"] = "冲动" }))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord { $0["moodIntensity"] = NSNull() }))
    }

    func testRejectsDuplicateUUIDAndUnknownDimensionWithoutPartialResult() throws {
        let data = try mutatedArchive { object in
            let records = object["records"] as! [[String: Any]]
            object["records"] = [records[0], records[0]]
            object["recordCount"] = 2
        }
        XCTAssertThrowsError(try RecordArchive.importEntries(from: data)) { error in
            XCTAssertTrue(error.localizedDescription.contains("重复"))
        }
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord {
            $0["domain"] = ["key": "unknown", "name": "未知维度"]
        }))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord {
            $0["domain"] = ["key": "career", "name": "错误名称"]
        }))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedRecord { $0["id"] = "invalid-id" }))
    }

    func testRejectsOversizedFilesAndMalformedMetadata() throws {
        XCTAssertThrowsError(try RecordArchive.importEntries(from: Data(repeating: 0, count: RecordArchive.maximumImportBytes + 1))) { error in
            XCTAssertTrue(error.localizedDescription.contains("20 MB"))
        }
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedArchive { $0["recordCount"] = 999 }))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedArchive { $0["timeZone"] = "Invalid/Zone" }))
        XCTAssertThrowsError(try RecordArchive.importEntries(from: mutatedArchive { $0["exportedAt"] = "yesterday" }))
    }

    func testExportsARecognizableJSONFileAndImportsItAgain() throws {
        let original = entry()
        let url = try RecordArchive.export(entries: [original], scope: .all, format: .json,
                                            timeZone: zone, exportedAt: exportedAt)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertTrue(url.lastPathComponent.hasPrefix("WhoAmI_全部记录_"))
        XCTAssertEqual(url.pathExtension, "json")
        XCTAssertEqual(try RecordArchive.importEntries(from: url).map(\.id), [original.id])
    }

    func testEmptyArchiveRemainsValidWithoutInventedRecords() throws {
        let data = try archive([entry(isDemo: true)])
        XCTAssertTrue(try RecordArchive.importEntries(from: data).isEmpty)
        let text = try XCTUnwrap(String(data: archive([], format: .markdown), encoding: .utf8))
        XCTAssertTrue(text.contains("- 记录数：0"))
        XCTAssertFalse(text.contains("## 记录 001"))
    }
}

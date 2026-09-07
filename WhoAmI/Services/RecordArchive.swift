import Foundation
import CoreFoundation

/// A versioned, portable archive of saved records. Drafts never enter this format.
enum RecordArchive {
    static let maximumImportBytes = 20 * 1_024 * 1_024

    enum Format: String, CaseIterable, Identifiable {
        case markdown, json
        var id: String { rawValue }
        var title: String { self == .markdown ? "Markdown" : "JSON" }
        var fileExtension: String { self == .markdown ? "md" : "json" }
    }

    enum Scope {
        case all
        case day(Date)
    }

    enum ArchiveError: LocalizedError {
        case tooLarge, unreadable, invalidJSON, unsupportedFormat, unsupportedVersion
        case invalidMetadata, invalidRecord(Int, String), duplicateID, writeFailed

        var errorDescription: String? {
            switch self {
            case .tooLarge: "文件超过 20 MB。请按日期拆分后导入。"
            case .unreadable: "无法读取这个文件。请在“文件”中确认文件已下载且可以访问。"
            case .invalidJSON: "文件内容不是有效的 WhoAmI JSON 记录档案。"
            case .unsupportedFormat: "请选择由 WhoAmI 导出的 JSON 文件。Markdown 用于阅读和 AI 分析，不能导入。"
            case .unsupportedVersion: "暂不支持此档案版本。请使用 schemaVersion 为 1 的 WhoAmI JSON 文件。"
            case .invalidMetadata: "档案的导出时间、时区、范围或记录数量不完整。未导入任何记录。"
            case let .invalidRecord(index, reason): "第 \(index) 条记录\(reason)。未导入任何记录。"
            case .duplicateID: "文件内含重复的记录 ID。请检查原始档案后再导入。"
            case .writeFailed: "无法生成导出文件。请检查设备可用空间后重试。"
            }
        }
    }

    private struct Archive: Codable {
        var format: String
        var schemaVersion: Int
        var exportedAt: String
        var timeZone: String
        var scope: ScopeDescription
        var recordCount: Int
        var records: [Record]
    }

    private struct ScopeDescription: Codable {
        var kind: String
        var date: String?
    }

    private struct Domain: Codable {
        var key: String
        var name: String
    }

    private struct Record: Codable {
        var id: String
        var title: String
        var body: String
        var createdAt: String
        var updatedAt: String?
        var domain: Domain?
        var moodIntensity: Int?
        var moodBand: String?
        var legacyMood: String?
        var projectID: String?

        // Explicit nulls distinguish missing historical measurements from zero.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encode(body, forKey: .body)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encode(domain, forKey: .domain)
            try container.encode(moodIntensity, forKey: .moodIntensity)
            try container.encode(moodBand, forKey: .moodBand)
            try container.encode(legacyMood, forKey: .legacyMood)
            try container.encode(projectID, forKey: .projectID)
        }
    }

    static func filteredEntries(_ entries: [JournalEntry], scope: Scope,
                                timeZone: TimeZone = .current) -> [JournalEntry] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let interval: DateInterval?
        switch scope {
        case .all: interval = nil
        case let .day(date): interval = calendar.dateInterval(of: .day, for: date)
        }
        return entries.filter { entry in
            guard !entry.isDemo else { return false }
            switch scope {
            case .all: return true
            case .day:
                guard let interval else { return false }
                return entry.createdAt >= interval.start && entry.createdAt < interval.end
            }
        }.sorted {
            $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt
        }
    }

    static func data(entries: [JournalEntry], scope: Scope, format: Format,
                     timeZone: TimeZone = .current, exportedAt: Date = .now) throws -> Data {
        let selected = filteredEntries(entries, scope: scope, timeZone: timeZone)
        let scopeDescription: ScopeDescription
        switch scope {
        case .all: scopeDescription = ScopeDescription(kind: "all", date: nil)
        case let .day(date): scopeDescription = ScopeDescription(kind: "day", date: dateLabel(date, timeZone: timeZone))
        }
        let archive = Archive(format: "whoami.records", schemaVersion: 1,
            exportedAt: timestamp(exportedAt, timeZone: timeZone), timeZone: timeZone.identifier,
            scope: scopeDescription, recordCount: selected.count,
            records: selected.map { entry in
                Record(id: entry.id.uuidString, title: entry.title, body: entry.body,
                    createdAt: timestamp(entry.createdAt, timeZone: timeZone),
                    updatedAt: entry.updatedAt.map { timestamp($0, timeZone: timeZone) },
                    domain: entry.domain.map { Domain(key: $0.rawValue, name: $0.title) },
                    moodIntensity: entry.moodIntensity,
                    moodBand: entry.moodIntensity.map { MoodBand.title(for: $0) },
                    legacyMood: entry.mood?.rawValue, projectID: entry.projectID?.uuidString)
            })
        // Never produce a JSON archive that this version cannot safely import.
        _ = try validate(archive)
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(archive)
        case .markdown:
            return Data(markdown(archive).utf8)
        }
    }

    static func export(entries: [JournalEntry], scope: Scope, format: Format,
                       timeZone: TimeZone = .current, exportedAt: Date = .now) throws -> URL {
        let contents = try data(entries: entries, scope: scope, format: format,
                                timeZone: timeZone, exportedAt: exportedAt)
        let scopeLabel: String
        switch scope {
        case .all: scopeLabel = "全部记录"
        case let .day(date): scopeLabel = dateLabel(date, timeZone: timeZone)
        }
        let exportLabel = dateFormatter("yyyyMMdd-HHmmss", timeZone: timeZone).string(from: exportedAt)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WhoAmI-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("WhoAmI_\(scopeLabel)_\(exportLabel).\(format.fileExtension)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try contents.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw ArchiveError.writeFailed
        }
    }

    static func importEntries(from url: URL) throws -> [JournalEntry] {
        guard url.pathExtension.lowercased() == "json" else { throw ArchiveError.unsupportedFormat }
        let contents: Data
        do {
            let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard info.isRegularFile == true else { throw ArchiveError.unreadable }
            guard (info.fileSize ?? maximumImportBytes + 1) <= maximumImportBytes else { throw ArchiveError.tooLarge }
            contents = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch let error as ArchiveError {
            throw error
        } catch {
            throw ArchiveError.unreadable
        }
        return try importEntries(from: contents)
    }

    static func importEntries(from data: Data) throws -> [JournalEntry] {
        guard data.count <= maximumImportBytes else { throw ArchiveError.tooLarge }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ArchiveError.invalidJSON
        }
        guard object["format"] as? String == "whoami.records" else { throw ArchiveError.unsupportedFormat }
        // Check the version before decoding so future schemas get an actionable error.
        guard let version = object["schemaVersion"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version.doubleValue == 1 else {
            throw ArchiveError.unsupportedVersion
        }
        let archive: Archive
        do {
            archive = try JSONDecoder().decode(Archive.self, from: data)
        } catch {
            throw ArchiveError.invalidJSON
        }
        return try validate(archive)
    }

    private static func validate(_ archive: Archive) throws -> [JournalEntry] {
        guard archive.format == "whoami.records" else { throw ArchiveError.unsupportedFormat }
        guard archive.schemaVersion == 1 else { throw ArchiveError.unsupportedVersion }
        guard parseTimestamp(archive.exportedAt) != nil,
              let timeZone = TimeZone(identifier: archive.timeZone),
              archive.recordCount == archive.records.count else { throw ArchiveError.invalidMetadata }
        let dayInterval: DateInterval?
        switch archive.scope.kind {
        case "all":
            guard archive.scope.date == nil else { throw ArchiveError.invalidMetadata }
            dayInterval = nil
        case "day":
            guard let label = archive.scope.date, let day = parseDay(label, timeZone: timeZone) else {
                throw ArchiveError.invalidMetadata
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            dayInterval = calendar.dateInterval(of: .day, for: day)
            guard dayInterval != nil else { throw ArchiveError.invalidMetadata }
        default: throw ArchiveError.invalidMetadata
        }

        var seen = Set<UUID>()
        return try archive.records.enumerated().map { index, record in
            func invalid(_ reason: String) -> ArchiveError { .invalidRecord(index + 1, reason) }
            guard let id = UUID(uuidString: record.id) else { throw invalid("的 ID 无效") }
            guard seen.insert(id).inserted else { throw ArchiveError.duplicateID }
            guard let createdAt = parseTimestamp(record.createdAt) else { throw invalid("的记录时间无效") }
            if let interval = dayInterval, !(createdAt >= interval.start && createdAt < interval.end) {
                throw invalid("的时间不属于档案指定日期")
            }
            var updatedAt: Date?
            if let text = record.updatedAt {
                guard let parsed = parseTimestamp(text), parsed >= createdAt else { throw invalid("的更新时间无效") }
                updatedAt = parsed
            }
            var domain: LifeDomain?
            if let value = record.domain {
                guard let parsed = LifeDomain(rawValue: value.key), parsed.title == value.name else {
                    throw invalid("的维度不受支持或名称不匹配")
                }
                domain = parsed
            }
            if let intensity = record.moodIntensity {
                guard (1...99).contains(intensity) else { throw invalid("的心境数值必须在 1 至 99 之间") }
                guard record.moodBand == MoodBand.title(for: intensity) else { throw invalid("的心境名称与数值不匹配") }
            } else if record.moodBand != nil {
                throw invalid("缺少心境数值，却包含心境名称")
            }
            var mood: Mood?
            if let rawMood = record.legacyMood {
                guard let parsed = Mood(rawValue: rawMood) else { throw invalid("的历史心情类型不受支持") }
                mood = parsed
            }
            var projectID: UUID?
            if let text = record.projectID {
                guard let parsed = UUID(uuidString: text) else { throw invalid("的项目 ID 无效") }
                projectID = parsed
            }
            return JournalEntry(id: id, title: record.title, body: record.body, createdAt: createdAt,
                domain: domain, mood: mood, projectID: projectID, isDemo: false,
                moodIntensity: record.moodIntensity, updatedAt: updatedAt)
        }
    }

    private static func timestamp(_ date: Date, timeZone: TimeZone) -> String {
        // Truncate, rather than round, so 23:59:59.9998 remains in its saved day.
        let milliseconds = floor(date.timeIntervalSince1970 * 1_000) / 1_000
        return dateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", timeZone: timeZone)
            .string(from: Date(timeIntervalSince1970: milliseconds))
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(Z|[+-]\d{2}:\d{2})$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let offset: Int
        if value.hasSuffix("Z") {
            offset = 0
        } else {
            let suffix = String(value.suffix(6))
            guard let hours = Int(suffix.dropFirst().prefix(2)), hours <= 23,
                  let minutes = Int(suffix.suffix(2)), minutes <= 59 else { return nil }
            offset = (hours * 3_600 + minutes * 60) * (suffix.hasPrefix("-") ? -1 : 1)
        }
        guard let zone = TimeZone(secondsFromGMT: offset) else { return nil }
        let formatter = dateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", timeZone: zone)
        guard let date = formatter.date(from: value) else { return nil }
        let canonical = offset == 0 ? String(value.prefix(23)) + "Z" : value
        guard formatter.string(from: date) == canonical else { return nil }
        return date
    }

    private static func dateLabel(_ date: Date, timeZone: TimeZone) -> String {
        // DateFormatter can round a submillisecond midnight boundary even when
        // its format omits seconds. Calendar components retain the actual day.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return String(format: "%04d-%02d-%02d", calendar.component(.year, from: date),
                      calendar.component(.month, from: date), calendar.component(.day, from: date))
    }

    private static func parseDay(_ value: String, timeZone: TimeZone) -> Date? {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let formatter = dateFormatter("yyyy-MM-dd", timeZone: timeZone)
        guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }
        return date
    }

    private static func dateFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }

    private static func markdown(_ archive: Archive) -> String {
        let range = archive.scope.kind == "all" ? "全部已保存记录" : archive.scope.date ?? ""
        var text = """
        # WhoAmI 记录档案

        - 格式：whoami.records.markdown
        - 版本：1
        - 导出时间：\(archive.exportedAt)
        - 时区：\(archive.timeZone)
        - 范围：\(range)
        - 记录数：\(archive.recordCount)
        - 心境区间：1–33 淡漠；34–66 平静；67–99 冲动；未记录表示缺少测量。

        正文代码块内为原始记录，保留换行与标点。本文件用于阅读和 AI 分析；恢复到 WhoAmI 请使用 JSON 档案。
        """
        for (index, record) in archive.records.enumerated() {
            let domain = record.domain.map { "\($0.name)（\($0.key)）" } ?? "未指定"
            let mood = record.moodIntensity.map { "\($0) / \(MoodBand.title(for: $0))" } ?? "未记录"
            let titleData = try? JSONEncoder().encode(record.title)
            let title = titleData.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
            let fence = String(repeating: "`", count: max(3, longestBacktickRun(record.body) + 1))
            text += """


            ## 记录 \(String(format: "%03d", index + 1))

            - ID：\(record.id)
            - 记录时间：\(record.createdAt)
            - 更新时间：\(record.updatedAt ?? "未修改")
            - 维度：\(domain)
            - 心境：\(mood)
            - 标题（JSON 字符串）：\(title)

            ### 正文

            \(fence)text
            """
            text += "\n" + record.body
            if !record.body.hasSuffix("\n") { text += "\n" }
            text += fence
        }
        return text + "\n"
    }

    private static func longestBacktickRun(_ text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            current = character == "`" ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}

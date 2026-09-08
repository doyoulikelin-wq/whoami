import SwiftUI
import Combine

enum LifeDomain: String, CaseIterable, Codable, Identifiable {
    case career, finance, body, emotion, learning, relationships, life
    var id: String { rawValue }
    var title: String {
        switch self {
        case .career: "事业与创造"
        case .finance: "财务与资源"
        case .body: "身体与精力"
        case .emotion: "情绪与应对"
        case .learning: "学习与认知"
        case .relationships: "关系与边界"
        case .life: "生活与自主"
        }
    }
    var shortTitle: String {
        switch self {
        case .career: "事业"
        case .finance: "财务"
        case .body: "身体"
        case .emotion: "情绪"
        case .learning: "学习"
        case .relationships: "关系"
        case .life: "生活"
        }
    }
    var icon: String {
        switch self {
        case .career: "briefcase"
        case .finance: "wallet.bifold"
        case .body: "figure.walk"
        case .emotion: "leaf"
        case .learning: "book.closed"
        case .relationships: "person.2"
        case .life: "sun.horizon"
        }
    }
    var color: Color {
        switch self {
        case .career: Color(hex: 0x506070)
        case .finance: Color(hex: 0x62737D)
        case .body: Color(hex: 0x667773)
        case .emotion: Color(hex: 0x6D6B7B)
        case .learning: Color(hex: 0x555F69)
        case .relationships: Color(hex: 0x586877)
        case .life: Color(hex: 0x75746D)
        }
    }
}

enum Mood: String, CaseIterable, Codable, Identifiable {
    case calm, happy, focused, tired, low
    var id: String { rawValue }
    var title: String {
        switch self {
        case .calm: "平静"
        case .happy: "愉快"
        case .focused: "专注"
        case .tired: "疲惫"
        case .low: "低落"
        }
    }
    var icon: String {
        switch self {
        case .calm: "leaf"
        case .happy: "sun.max"
        case .focused: "scope"
        case .tired: "moon"
        case .low: "cloud"
        }
    }
}

struct JournalEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var createdAt: Date
    var domain: LifeDomain?
    var mood: Mood?
    var projectID: UUID? = nil
    var isDemo = false
    var moodIntensity: Int? = nil
    var updatedAt: Date? = nil
}

struct GrowthProject: Identifiable, Codable {
    var id = UUID()
    var title: String
    var summary: String
    var domain: LifeDomain
    var progress: Double
    var nextStep: String
    var isDemo = false
}

struct OpenQuestion: Identifiable, Codable {
    var id = UUID()
    var title: String
    var note: String
    var isDemo = false
}

struct ReviewReport: Identifiable, Codable {
    var id = UUID()
    var createdAt: Date
    var periodStart: Date
    var periodEnd: Date
    var entryIDs: [UUID]
    var summary: String
    var observation: String
    var hypothesis: String
    var action: String
    var feedback = ""
    var actionDone = false
    var isDemo = false
    var isLocal = true
}

private struct StoreSnapshot: Codable {
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
    var dimensionDrafts: [String: DimensionDraft]?
    var recordingDomain: LifeDomain?
    var recordingModeVersion: Int?
}

struct RecordImportResult {
    let added: Int
    let skipped: Int
}

enum RecordImportError: LocalizedError {
    case unavailable
    case saveFailed
    var errorDescription: String? {
        switch self {
        case .unavailable: "本地记录尚未成功读取，无法合并导入。原文件已保留。"
        case .saveFailed: "导入未能保存，现有记录未改变。请检查设备存储空间后重试。"
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var entries: [JournalEntry] = [] { didSet { persist() } }
    @Published var projects: [GrowthProject] = [] { didSet { persist() } }
    @Published var questions: [OpenQuestion] = [] { didSet { persist() } }
    @Published var reviews: [ReviewReport] = [] { didSet { persist() } }
    @Published var mood: Mood? = nil { didSet { persist() } }
    @Published var energy = 3 { didSet { persist() } }
    @Published var reviewInterval = 3 { didSet { persist() } }
    @Published var focus = "核对目标、投入与结果" { didSet { persist() } }
    @Published var draftText = "" { didSet { persist() } }
    @Published var draftDomain: LifeDomain? { didSet { persist() } }
    @Published var draftMood: Mood? { didSet { persist() } }
    @Published var draftProjectID: UUID? { didSet { persist() } }
    @Published var dimensionDrafts: [String: DimensionDraft] = [:] { didSet { persist() } }
    @Published var recordingDomain: LifeDomain = .career { didSet { persist() } }
    @Published var storageError: String?
    private var ready = false
    private var recordingModeVersion = 1
    private let fileURL: URL

    init(fileURL: URL? = nil, arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("whoami-v1.json")
        if arguments.contains("--uitesting-reset") {
            try? FileManager.default.removeItem(at: self.fileURL)
        }
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do {
                let data = try Data(contentsOf: self.fileURL)
                let saved = try JSONDecoder().decode(StoreSnapshot.self, from: data)
                entries = saved.entries; projects = saved.projects
                questions = saved.questions; reviews = saved.reviews
                mood = saved.mood; energy = saved.energy
                reviewInterval = saved.reviewInterval; focus = saved.focus
                draftText = saved.draftText; draftDomain = saved.draftDomain
                draftMood = saved.draftMood; draftProjectID = saved.draftProjectID
                dimensionDrafts = saved.dimensionDrafts ?? [:]
                recordingDomain = saved.recordingDomain ?? .career
                recordingModeVersion = saved.recordingModeVersion ?? 0
            } catch {
                storageError = "暂时无法读取本地记录。原文件已保留，请先导出备份。"
                return
            }
        }
        // Prune only explicitly marked samples. User records and all drafts remain intact.
        clearExamples()
        if recordingModeVersion < 1 {
            // Old versions kept a saved record in the editor. Retain genuine edits,
            // but discard exact saved copies once when entering independent-entry mode.
            for domain in LifeDomain.allCases {
                guard let draft = dimensionDrafts[domain.rawValue],
                      draft.hasChosenIntensity,
                      let saved = latestRecord(for: domain),
                      draft.body == saved.body, draft.intensity == saved.moodIntensity else { continue }
                dimensionDrafts[domain.rawValue] = DimensionDraft()
            }
            recordingModeVersion = 1
        }
        ready = true
        persist()
    }

    var sortedEntries: [JournalEntry] { entries.sorted { $0.createdAt > $1.createdAt } }
    var realEntries: [JournalEntry] { sortedEntries.filter { !$0.isDemo } }
    var hasExamples: Bool { entries.contains(where: \.isDemo) || projects.contains(where: \.isDemo) }
    var energyLabel: String { ["精力很低", "精力偏低", "精力中等", "精力较高", "精力很高"][min(max(energy, 1), 5) - 1] }
    func entry(_ id: UUID) -> JournalEntry? { entries.first { $0.id == id } }
    func entries(in domain: LifeDomain) -> [JournalEntry] { sortedEntries.filter { $0.domain == domain } }

    @discardableResult
    func saveDraft() -> JournalEntry? {
        let body = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        let firstLine = body.components(separatedBy: .newlines).first ?? body
        let entry = JournalEntry(title: String(firstLine.prefix(26)), body: body, createdAt: .now,
                                 domain: draftDomain, mood: draftMood, projectID: draftProjectID)
        entries.append(entry)
        draftText = ""; draftDomain = nil; draftMood = nil; draftProjectID = nil
        return entry
    }

    func latestRecord(for domain: LifeDomain) -> JournalEntry? {
        realEntries.first { $0.domain == domain }
    }

    func dimensionDraft(for domain: LifeDomain) -> DimensionDraft {
        if let draft = dimensionDrafts[domain.rawValue] { return draft }
        // Retain unfinished content from the previous single-draft editor.
        if (draftDomain == domain || (draftDomain == nil && domain == .career)) && !draftText.isEmpty {
            return DimensionDraft(body: draftText)
        }
        return DimensionDraft()
    }

    func setDimensionDraft(_ draft: DimensionDraft, for domain: LifeDomain) {
        dimensionDrafts[domain.rawValue] = DimensionDraft(body: draft.body,
            intensity: min(99, max(1, draft.intensity)), hasChosenIntensity: draft.hasChosenIntensity)
    }

    var savedDimensionLevels: [LifeDomain: Int] { savedDimensionLevels(on: .now) }

    func savedDimensionLevels(on date: Date, calendar: Calendar = .current) -> [LifeDomain: Int] {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return [:] }
        let today = realEntries.filter { $0.createdAt >= day.start && $0.createdAt < day.end }
        return Dictionary(uniqueKeysWithValues: LifeDomain.allCases.compactMap { domain in
            guard let level = today.first(where: { $0.domain == domain })?.moodIntensity else { return nil }
            return (domain, min(99, max(1, level)))
        })
    }

    @discardableResult
    func saveDimension(_ domain: LifeDomain, at date: Date = .now) -> JournalEntry? {
        guard ready else {
            storageError = "本地记录尚未成功读取，原文件已保留。"
            return nil
        }
        let draft = dimensionDraft(for: domain)
        let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, draft.hasChosenIntensity else { return nil }
        let firstLine = body.components(separatedBy: .newlines).first ?? body
        let entry = JournalEntry(title: String(firstLine.prefix(26)), body: body, createdAt: date,
                                 domain: domain, mood: nil, moodIntensity: min(99, max(1, draft.intensity)), updatedAt: date)
        var next = snapshot
        next.entries.append(entry)
        var nextDrafts = dimensionDrafts
        nextDrafts[domain.rawValue] = DimensionDraft()
        next.dimensionDrafts = nextDrafts
        if draftDomain == domain || (draftDomain == nil && domain == .career) {
            next.draftText = ""; next.draftDomain = nil; next.draftMood = nil; next.draftProjectID = nil
        }
        do {
            // The new entry and empty next draft are committed together.
            try JSONEncoder().encode(next).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            storageError = "本次记录尚未保存，输入内容已保留。请稍后重试。"
            return nil
        }
        ready = false
        entries = next.entries
        dimensionDrafts = nextDrafts
        draftText = next.draftText; draftDomain = next.draftDomain
        draftMood = next.draftMood; draftProjectID = next.draftProjectID
        ready = true
        storageError = nil
        return entry
    }

    func update(_ entry: JournalEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
    }

    func deleteEntry(_ id: UUID) { entries.removeAll { $0.id == id } }
    func updateReview(_ review: ReviewReport) {
        guard let index = reviews.firstIndex(where: { $0.id == review.id }) else { return }
        reviews[index] = review
    }
    func updateProject(_ project: GrowthProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
    }
    func updateQuestion(_ question: OpenQuestion) {
        guard let index = questions.firstIndex(where: { $0.id == question.id }) else { return }
        questions[index] = question
    }

    func clearExamples() {
        entries.removeAll(where: \.isDemo)
        projects.removeAll(where: \.isDemo)
        questions.removeAll(where: \.isDemo)
        reviews.removeAll(where: \.isDemo)
    }

    @discardableResult
    func importRecords(_ records: [JournalEntry]) throws -> RecordImportResult {
        guard ready else { throw RecordImportError.unavailable }
        var knownIDs = Set(entries.map(\.id))
        let additions = records.filter { !$0.isDemo && knownIDs.insert($0.id).inserted }
        let result = RecordImportResult(added: additions.count, skipped: records.count - additions.count)
        guard !additions.isEmpty else { return result }
        var next = snapshot
        next.entries.append(contentsOf: additions)
        do {
            // Commit before publishing so failed imports cannot replace in-memory data.
            let data = try JSONEncoder().encode(next)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            throw RecordImportError.saveFailed
        }
        ready = false
        entries = next.entries
        ready = true
        storageError = nil
        return result
    }

    @discardableResult
    func createLocalReview() -> ReviewReport {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -(reviewInterval - 1), to: Calendar.current.startOfDay(for: now))!
        let selected = realEntries.filter { $0.createdAt >= start && $0.createdAt <= now }
        let domains = Set(selected.compactMap(\.domain))
        let summary = selected.isEmpty ? "所选时段没有真实记录，无法整理回顾。" :
            "最近 \(reviewInterval) 天，你留下了 \(selected.count) 条记录，涉及 \(domains.count) 个观察维度。原文列在下方。"
        let report = ReviewReport(createdAt: now, periodStart: start, periodEnd: now,
            entryIDs: selected.map(\.id), summary: summary,
            observation: selected.count < 3 ? "记录数量较少，不足以判断持续变化。" : "逐条核对事件、反应和结果，确认是否存在重复情况。",
            hypothesis: "本回顾仅按日期与标签整理记录。AI 分析尚未接入，不推断动机或长期状态。",
            action: "列出一项可执行的行动，并记录完成时间与结果。")
        reviews.insert(report, at: 0)
        return report
    }

    private var snapshot: StoreSnapshot {
        StoreSnapshot(entries: entries, projects: projects, questions: questions, reviews: reviews,
                      mood: mood, energy: energy, reviewInterval: reviewInterval, focus: focus,
                      draftText: draftText, draftDomain: draftDomain, draftMood: draftMood, draftProjectID: draftProjectID,
                      dimensionDrafts: dimensionDrafts, recordingDomain: recordingDomain, recordingModeVersion: recordingModeVersion)
    }
    private func persist() {
        guard ready else { return }
        do {
            try JSONEncoder().encode(snapshot).write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            storageError = "本地保存暂未成功，请保留当前内容后重试。"
        }
    }
}

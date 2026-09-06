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
    private let fileURL: URL

    init() {
        fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("whoami-v1.json")
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting-reset") {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let data = try? Data(contentsOf: fileURL) {
            do {
                let saved = try JSONDecoder().decode(StoreSnapshot.self, from: data)
                entries = saved.entries; projects = saved.projects
                questions = saved.questions; reviews = saved.reviews
                mood = saved.mood; energy = saved.energy
                reviewInterval = saved.reviewInterval; focus = saved.focus
                draftText = saved.draftText; draftDomain = saved.draftDomain
                draftMood = saved.draftMood; draftProjectID = saved.draftProjectID
                dimensionDrafts = saved.dimensionDrafts ?? [:]
                recordingDomain = saved.recordingDomain ?? .career
            } catch {
                storageError = "暂时无法读取本地记录。原文件已保留，请先导出备份。"
                return
            }
        } else if !arguments.contains("--uitesting-empty") {
            installExamples()
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
        if let saved = latestRecord(for: domain) {
            return DimensionDraft(body: saved.body, intensity: saved.moodIntensity ?? 50,
                                  hasChosenIntensity: saved.moodIntensity != nil)
        }
        return DimensionDraft()
    }

    func setDimensionDraft(_ draft: DimensionDraft, for domain: LifeDomain) {
        dimensionDrafts[domain.rawValue] = DimensionDraft(body: draft.body,
            intensity: min(99, max(1, draft.intensity)), hasChosenIntensity: draft.hasChosenIntensity)
    }

    var savedDimensionLevels: [LifeDomain: Int] {
        Dictionary(uniqueKeysWithValues: LifeDomain.allCases.compactMap { domain in
            guard let level = latestRecord(for: domain)?.moodIntensity else { return nil }
            return (domain, min(99, max(1, level)))
        })
    }

    @discardableResult
    func saveDimension(_ domain: LifeDomain) -> JournalEntry? {
        let draft = dimensionDraft(for: domain)
        let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, draft.hasChosenIntensity else { return nil }
        let level = min(99, max(1, draft.intensity))
        let latest = latestRecord(for: domain)
        // Repeated taps without edits reuse the existing snapshot.
        if let latest, latest.body == body, latest.moodIntensity == level {
            setDimensionDraft(DimensionDraft(body: body, intensity: level, hasChosenIntensity: true), for: domain)
            return latest
        }
        let firstLine = body.components(separatedBy: .newlines).first ?? body
        let entry = JournalEntry(title: String(firstLine.prefix(26)), body: body, createdAt: .now,
                                 domain: domain, mood: nil, moodIntensity: level, updatedAt: .now)
        entries.append(entry)
        setDimensionDraft(DimensionDraft(body: body, intensity: level, hasChosenIntensity: true), for: domain)
        if draftDomain == domain || (draftDomain == nil && domain == .career) { draftText = ""; draftDomain = nil; draftMood = nil; draftProjectID = nil }
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
        let removedProjects = Set(projects.filter(\.isDemo).map(\.id))
        entries.removeAll(where: \.isDemo)
        for index in entries.indices {
            if let id = entries[index].projectID, removedProjects.contains(id) { entries[index].projectID = nil }
        }
        if let id = draftProjectID, removedProjects.contains(id) { draftProjectID = nil }
        projects.removeAll(where: \.isDemo)
        questions.removeAll(where: \.isDemo)
        reviews.removeAll(where: \.isDemo)
    }

    func installExamples() {
        guard !hasExamples else { return }
        let today = Calendar.current.startOfDay(for: .now)
        func day(_ offset: Int, _ hour: Int) -> Date {
            Calendar.current.date(byAdding: .hour, value: hour,
                to: Calendar.current.date(byAdding: .day, value: offset, to: today)!)!
        }
        let project = GrowthProject(title: "个人记录 App", summary: "验证从输入到复盘的完整流程，记录错误与未完成项。",
                                    domain: .career, progress: 0.35, nextStep: "完成记录流程验证", isDemo: true)
        projects.append(contentsOf: [project, GrowthProject(title: "完成一本书的阅读", summary: "按章节记录论点、证据与待核实的问题。",
                    domain: .learning, progress: 0.6, nextStep: "完成一章并列出论据", isDemo: true)])
        questions.append(contentsOf: [OpenQuestion(title: "我的时间投入是否对应当前目标？", note: "比较计划用时、实际用时与产生的结果。", isDemo: true),
                     OpenQuestion(title: "继续准备解决了哪个具体障碍？", note: "记录每次修改的理由，区分必要准备与延迟交付。", isDemo: true)])
        var examples = [
            JournalEntry(title: "先验证，再扩展", body: "今天用一个可操作的页面验证记录流程。我完成了输入、保存和重新打开三个步骤，发现日期筛选还没有验证。\n\n页面能运行让我暂时停止扩展功能，但这不等于流程已通过测试。下一步检查空记录和重启后的数据。", createdAt: day(0, 9), domain: .learning, mood: .focused, projectID: project.id, isDemo: true),
            JournalEntry(title: "交付标准仍不明确", body: "今天用 45 分钟修改了三版页面，但没有写出验收条件。遇到布局问题后，我感到焦躁，继续调整了间距和颜色。\n\n这些修改没有解决交付范围的问题。我需要先列出本次必须完成的功能。", createdAt: day(-1, 19), domain: .career, mood: .calm, projectID: project.id, isDemo: true),
            JournalEntry(title: "散步前后的状态", body: "下午连续坐了两个小时，我开始反复切换窗口，注意力难以维持。傍晚步行 30 分钟后，主观疲劳感下降。\n\n返回桌面后，我列出了原问题的两个处理方向。一次记录不足以判断变化是否由散步引起。", createdAt: day(-1, 17), domain: .body, mood: .happy, isDemo: true),
            JournalEntry(title: "四十分钟的实际投入", body: "我关闭消息提醒，安排了 40 分钟阅读。实际阅读约 25 分钟，其余时间用于查资料。\n\n原计划完成一章，最后没有完成。我记下了两个需要核实的问题，下一次要把查阅时间单独计算。", createdAt: day(-2, 10), domain: .life, mood: .calm, isDemo: true),
            JournalEntry(title: "本月资金与固定支出", body: "我核对了本月账目。示例存款为 28,600 元，每月固定支出为 5,400 元，未到账收入没有计入存款。\n\n看到支出总额后，我感到紧张。目前还没有决定削减哪一项，需要先区分必要支出和可调整支出。", createdAt: day(-3, 20), domain: .finance, mood: .calm, isDemo: true)
        ]
        for index in examples.indices { examples[index].moodIntensity = [52, 81, 43, 26, 69][index] }
        entries.append(contentsOf: examples)
        reviews.append(ReviewReport(createdAt: .now, periodStart: day(-2, 0), periodEnd: .now,
            entryIDs: Array(examples.prefix(4).map(\.id)),
            summary: "这段示例包含 4 条记录，涉及原型验证、交付标准、身体状态和时间投入。记录中同时存在已完成步骤与未完成检查。",
            observation: "你完成了输入、保存和重新打开的操作，但日期筛选尚未验证。另一条记录显示，交付标准未明确时，你连续修改了三版页面。",
            hypothesis: "交付标准不明确可能使工作转向反复修改界面。现有四条示例不足以确定原因，也不能据此判断长期行为。",
            action: "为当前项目列出三条验收条件，完成一项后记录结果与耗时。", isDemo: true, isLocal: false))
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

    func exportFile() throws -> URL {
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("WhoAmI-记录备份.json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: target, options: [.atomic, .completeFileProtection])
        return target
    }

    private var snapshot: StoreSnapshot {
        StoreSnapshot(entries: entries, projects: projects, questions: questions, reviews: reviews,
                      mood: mood, energy: energy, reviewInterval: reviewInterval, focus: focus,
                      draftText: draftText, draftDomain: draftDomain, draftMood: draftMood, draftProjectID: draftProjectID,
                      dimensionDrafts: dimensionDrafts, recordingDomain: recordingDomain)
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

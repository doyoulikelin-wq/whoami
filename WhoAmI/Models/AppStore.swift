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
        case .career: Palette.coral
        case .finance: Color(hex: 0x92734E)
        case .body: Color(hex: 0x668983)
        case .emotion: Color(hex: 0x9A7893)
        case .learning: Palette.sage
        case .relationships: Color(hex: 0x6C86A4)
        case .life: Color(hex: 0xB38A43)
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
    @Published var focus = "把时间留给真正重要的事" { didSet { persist() } }
    @Published var draftText = "" { didSet { persist() } }
    @Published var draftDomain: LifeDomain? { didSet { persist() } }
    @Published var draftMood: Mood? { didSet { persist() } }
    @Published var draftProjectID: UUID? { didSet { persist() } }
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
    var energyLabel: String { ["需要休息", "精力偏低", "精力尚可", "精力充足", "充满活力"][min(max(energy, 1), 5) - 1] }
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
        let project = GrowthProject(title: "做一个自己的 App", summary: "从真实需要出发，先把最重要的体验做好。",
                                    domain: .career, progress: 0.35, nextStep: "完成第一版记录页面", isDemo: true)
        projects.append(contentsOf: [project, GrowthProject(title: "重新开始阅读", summary: "慢一点读，留下真正有用的想法。",
                    domain: .learning, progress: 0.6, nextStep: "读完一章，记下一个问题", isDemo: true)])
        questions.append(contentsOf: [OpenQuestion(title: "什么事情让我觉得时间花得值得？", note: "留意那些做完以后，内心更安定的时刻。", isDemo: true),
                     OpenQuestion(title: "我是在准备，还是在推迟开始？", note: "从一次具体的选择里寻找答案。", isDemo: true)])
        let examples = [
            JournalEntry(title: "先做出来，再慢慢变好", body: "今天专注解决一个小问题，虽然进度不大，但更有方向感了。\n\n比起想清楚所有细节，我更想先做一份能用的版本。", createdAt: day(0, 9), domain: .learning, mood: .focused, projectID: project.id, isDemo: true),
            JournalEntry(title: "给正在做的事一点耐心", body: "过程中遇到了一些阻力。提醒自己放慢节奏，把基础打好再说。\n\n今天把记录流程画了出来，下一步试试亲手用它。", createdAt: day(-1, 19), domain: .career, mood: .calm, projectID: project.id, isDemo: true),
            JournalEntry(title: "出去走走，想法也松动了", body: "傍晚散步了半小时。回来以后，那个卡了一下午的问题，似乎有了新的角度。", createdAt: day(-1, 17), domain: .body, mood: .happy, isDemo: true),
            JournalEntry(title: "把重要的事情放在前面", body: "关掉了消息提醒，留了四十分钟给自己。读了几页书，也记下了两个想继续想的问题。", createdAt: day(-2, 10), domain: .life, mood: .calm, isDemo: true),
            JournalEntry(title: "留一份自己的安全感", body: "整理了这个月的固定开支。示例存款为 28,600 元，先看清资源，再决定下一步。", createdAt: day(-3, 20), domain: .finance, mood: .calm, isDemo: true)
        ]
        entries.append(contentsOf: examples)
        reviews.append(ReviewReport(createdAt: .now, periodStart: day(-2, 0), periodEnd: .now,
            entryIDs: Array(examples.prefix(4).map(\.id)),
            summary: "这几天，你在做项目、阅读和散步之间，慢慢找到了自己的节奏。四段记录留下了这些变化。",
            observation: "从反复准备，到尝试做出一个小版本，你开始把注意力放在能完成的下一步。",
            hypothesis: "任务足够具体时，开始可能会更容易。这只是示例材料中的一种解释，还需要更多经历来验证。",
            action: "给最重要的项目留 25 分钟，只完成一个能展示的小部分。", isDemo: true, isLocal: false))
    }

    @discardableResult
    func createLocalReview() -> ReviewReport {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -(reviewInterval - 1), to: Calendar.current.startOfDay(for: now))!
        let selected = realEntries.filter { $0.createdAt >= start && $0.createdAt <= now }
        let domains = Set(selected.compactMap(\.domain))
        let summary = selected.isEmpty ? "这段时间还没有你的记录。先留下一个真实片段，回顾会从这里开始。" :
            "这 \(reviewInterval) 天，你留下了 \(selected.count) 条记录，涉及 \(domains.count) 个观察维度。以下保留了可以回看的原文。"
        let report = ReviewReport(createdAt: now, periodStart: start, periodEnd: now,
            entryIDs: selected.map(\.id), summary: summary,
            observation: selected.count < 3 ? "目前材料较少，暂不足以判断持续的变化。" : "从这些记录中，选一个你最想继续理解的时刻。",
            hypothesis: "这是按日期和标签整理的本地回顾。AI 分析尚未接入，不推断你的动机或长期状态。",
            action: "写下一个小行动，下次回来看看发生了什么。")
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
                      draftText: draftText, draftDomain: draftDomain, draftMood: draftMood, draftProjectID: draftProjectID)
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

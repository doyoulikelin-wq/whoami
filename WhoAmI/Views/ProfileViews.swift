import SwiftUI

struct ProfileHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingFocusEditor = false
    @State private var showingProjectEditor = false
    @State private var showingQuestionEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                PageHeading(eyebrow: "MY WORLD", title: "慢慢认识自己。", subtitle: "从在意的事，到正在成为的自己。")
                focusPanel
                domainsSection
                projectsSection
                questionsSection
                NavigationLink {
                    SettingsView()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 19)).foregroundStyle(Palette.sage)
                        Text("数据与设置").font(.system(size: 16, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                            .foregroundStyle(Palette.secondary)
                    }
                    .foregroundStyle(Palette.ink).padding(.vertical, 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
        }
        .pageBackground()
        .sheet(isPresented: $showingFocusEditor) { FocusEditorView().environmentObject(store) }
        .sheet(isPresented: $showingProjectEditor) { ProjectEditorView().environmentObject(store) }
        .sheet(isPresented: $showingQuestionEditor) { QuestionEditorView().environmentObject(store) }
    }

    private var focusPanel: some View {
        Button { showingFocusEditor = true } label: {
            HStack(spacing: 16) {
                Image("Companion")
                    .resizable().scaledToFill().frame(width: 138, height: 92)
                    .offset(x: -54).frame(width: 78, height: 92, alignment: .leading)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 23))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("现在，我更在意").font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "pencil").font(.system(size: 13))
                            .foregroundStyle(Palette.sage)
                    }
                    Text(store.focus.isEmpty ? "什么值得你留出时间？" : store.focus)
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading).lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18).background(Palette.cream, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑现在重视的事，\(store.focus)")
        .accessibilityIdentifier("profile.editFocus")
    }

    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "生活的不同切面")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(LifeDomain.allCases) { domain in
                    NavigationLink { DomainDetailView(domain: domain) } label: {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                DomainIcon(domain: domain, size: 34)
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.system(size: 11))
                                    .foregroundStyle(Palette.secondary)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(domain.title).font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Palette.ink)
                                Text(domainCount(domain)).font(.system(size: 11))
                                    .foregroundStyle(Palette.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 19))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func domainCount(_ domain: LifeDomain) -> String {
        let entries = store.entries(in: domain)
        if entries.isEmpty { return "等待一个生活片段" }
        let ownCount = entries.filter { !$0.isDemo }.count
        if ownCount == 0 { return "\(entries.count) 段示例记录" }
        return "\(ownCount) 段自己的记录"
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "正在投入的事", trailing: "添加") { showingProjectEditor = true }
                .accessibilityIdentifier("profile.projects")
            if store.projects.isEmpty {
                EmptyState(icon: "leaf", title: "给一件事留一点位置", detail: "可以是一个计划，也可以是想慢慢练习的事。")
            } else {
                ForEach(store.projects) { project in
                    NavigationLink { ProjectDetailView(projectID: project.id) } label: {
                        ProfileProjectRow(project: project)
                    }.buttonStyle(.plain)
                    if project.id != store.projects.last?.id { Divider().overlay(Palette.line) }
                }
            }
        }
    }

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "还在想的问题", trailing: "添加") { showingQuestionEditor = true }
                .accessibilityIdentifier("profile.questions")
            if store.questions.isEmpty {
                EmptyState(icon: "text.bubble", title: "答案可以慢慢来", detail: "先留下一个你想继续理解的问题。")
            } else {
                ForEach(store.questions) { question in
                    NavigationLink { QuestionDetailView(questionID: question.id) } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: "quote.opening").font(.system(size: 17))
                                .foregroundStyle(Palette.coral).padding(.top, 3)
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(alignment: .firstTextBaseline, spacing: 7) {
                                    Text(question.title).font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Palette.ink).lineSpacing(4)
                                    if question.isDemo { Text("示例").font(.system(size: 10)).foregroundStyle(Palette.secondary) }
                                }
                                if !question.note.isEmpty {
                                    Text(question.note).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                                        .lineLimit(2).lineSpacing(4)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 10))
                                .foregroundStyle(Palette.secondary).padding(.top, 6)
                        }.padding(.vertical, 17).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if question.id != store.questions.last?.id { Divider().overlay(Palette.line) }
                }
            }
        }
    }
}

private struct ProfileProjectRow: View {
    let project: GrowthProject
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                DomainIcon(domain: project.domain, size: 40)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(project.title).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                        if project.isDemo { Text("示例").font(.system(size: 10)).foregroundStyle(Palette.secondary) }
                    }
                    if !project.nextStep.isEmpty {
                        Text("下一步 · \(project.nextStep)").font(.system(size: 12))
                            .foregroundStyle(Palette.secondary).lineLimit(2).lineSpacing(3)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 10))
                    .foregroundStyle(Palette.secondary).padding(.top, 6)
            }
            HStack(spacing: 10) {
                ProgressView(value: min(max(project.progress, 0), 1)).tint(project.domain.color)
                Text("\(Int((min(max(project.progress, 0), 1) * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(Palette.secondary)
            }.padding(.leading, 52)
        }.padding(.vertical, 17).contentShape(Rectangle())
    }
}

struct ProjectDetailView: View {
    let projectID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var confirmingDelete = false
    private var project: GrowthProject? { store.projects.first { $0.id == projectID } }
    private var linkedEntries: [JournalEntry] { store.sortedEntries.filter { $0.projectID == projectID } }

    var body: some View {
        ScrollView {
            if let project {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            TagPill(text: project.domain.title, icon: project.domain.icon, color: project.domain.color, filled: true)
                            if project.isDemo { TagPill(text: "示例") }
                        }
                        Text(project.title).font(.system(size: 29, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink).lineSpacing(5)
                        if !project.summary.isEmpty {
                            Text(project.summary).font(.system(size: 16)).foregroundStyle(Palette.secondary).lineSpacing(7)
                        }
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Text("按自己的节奏").font(.subheadline).foregroundStyle(Palette.secondary)
                            Spacer()
                            Text("\(Int((min(max(project.progress, 0), 1) * 100).rounded()))%")
                                .font(.system(size: 18, weight: .medium)).monospacedDigit().foregroundStyle(project.domain.color)
                        }
                        ProgressView(value: min(max(project.progress, 0), 1)).tint(project.domain.color)
                        Text("进度由你自己定义。")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        Label("下一小步", systemImage: "arrow.turn.down.right")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.sage)
                        Text(project.nextStep.isEmpty ? "留一个小到愿意开始的行动。" : project.nextStep)
                            .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.ink).lineSpacing(6)
                    }.paperPanel()
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeading(title: "项目里的片段")
                        if linkedEntries.isEmpty {
                            EmptyState(icon: "text.alignleft", title: "还没有关联的记录", detail: "记录生活片段时，可以把它放进这个项目。")
                        } else {
                            ForEach(linkedEntries) { entry in
                                NavigationLink { EntryDetailView(entryID: entry.id) } label: { EntryRow(entry: entry) }
                                    .buttonStyle(.plain)
                                if entry.id != linkedEntries.last?.id { Divider().overlay(Palette.line) }
                            }
                        }
                    }
                    NavigationLink { DomainDetailView(domain: project.domain) } label: {
                        HStack(spacing: 10) {
                            Text("也看看\(project.domain.title)的其他片段")
                                .font(.system(size: 14)).foregroundStyle(Palette.sage)
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 12)).foregroundStyle(Palette.sage)
                        }.padding(.vertical, 14).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.padding(24)
            } else {
                EmptyState(icon: "archivebox", title: "这个项目已移除", detail: "与它相关的生活记录依然保留。")
            }
        }
        .pageBackground().navigationTitle("正在投入的事").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if project != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("编辑项目", systemImage: "pencil") { showingEditor = true }
                        Button("删除项目", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Palette.sage) }
                        .accessibilityLabel("项目操作")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let project { ProjectEditorView(project: project).environmentObject(store) }
        }
        .confirmationDialog("删除这个项目？相关记录会保留。", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除项目", role: .destructive) { deleteProject() }
            Button("取消", role: .cancel) { }
        }
    }

    private func deleteProject() {
        for index in store.entries.indices where store.entries[index].projectID == projectID {
            store.entries[index].projectID = nil
        }
        if store.draftProjectID == projectID { store.draftProjectID = nil }
        store.projects.removeAll { $0.id == projectID }
        dismiss()
    }
}

struct QuestionDetailView: View {
    let questionID: UUID
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var confirmingDelete = false
    private var question: OpenQuestion? { store.questions.first { $0.id == questionID } }

    var body: some View {
        ScrollView {
            if let question {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 19) {
                        HStack {
                            Image(systemName: "quote.opening").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.coral)
                            Spacer()
                            if question.isDemo { TagPill(text: "示例") }
                        }
                        Text(question.title).font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.ink).lineSpacing(8)
                        Text("不急着下结论，留意生活里的线索。")
                            .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(5)
                    }
                    Divider().overlay(Palette.line)
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "留给自己的线索")
                        Text(question.note.isEmpty ? "当你有了新的想法，可以随时回来补充。" : question.note)
                            .font(.system(size: 17)).foregroundStyle(question.note.isEmpty ? Palette.secondary : Palette.ink)
                            .lineSpacing(9).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button { showingEditor = true } label: {
                        Label("补充想法", systemImage: "pencil")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.sage)
                            .padding(.vertical, 13).padding(.horizontal, 18)
                            .background(Palette.sage.opacity(0.08), in: Capsule())
                    }.buttonStyle(.plain)
                }.padding(24)
            } else {
                EmptyState(icon: "text.bubble", title: "这个问题已移除", detail: "新的问题，随时可以再留下。")
            }
        }
        .pageBackground().navigationTitle("还在想的问题").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if question != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("编辑问题", systemImage: "pencil") { showingEditor = true }
                        Button("删除问题", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Palette.sage) }
                        .accessibilityLabel("问题操作")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let question { QuestionEditorView(question: question).environmentObject(store) }
        }
        .confirmationDialog("删除这个问题？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("删除问题", role: .destructive) {
                store.questions.removeAll { $0.id == questionID }
                dismiss()
            }
            Button("取消", role: .cancel) { }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exportURL: URL?
    @State private var confirmingClear = false
    private var exampleCount: Int {
        store.entries.filter(\.isDemo).count + store.projects.filter(\.isDemo).count
            + store.questions.filter(\.isDemo).count + store.reviews.filter(\.isDemo).count
    }

    var body: some View {
        Form {
            Section {
                Picker("复盘周期", selection: $store.reviewInterval) {
                    Text("每 2 天").tag(2)
                    Text("每 3 天").tag(3)
                    Text("每 4 天").tag(4)
                }.tint(Palette.sage)
            } header: { Text("适合自己的节奏") } footer: {
                Text("决定每次回顾涵盖多少天。什么时候回来看看，由你决定。")
            }

            Section {
                Label("保存在此设备，不上传云端", systemImage: "iphone")
                    .font(.system(size: 15))
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("导出记录备份", systemImage: "square.and.arrow.up")
                    }.tint(Palette.sage).accessibilityIdentifier("settings.export")
                } else {
                    Button { prepareExport() } label: {
                        Label("准备记录备份", systemImage: "square.and.arrow.up")
                    }.tint(Palette.sage)
                }
            } header: { Text("你的记录，自己保管") } footer: {
                Text("备份包含记录、项目、问题和复盘。卸载 App 会删除此设备上的数据，建议定期导出保存。")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("回顾从真实记录开始").font(.system(size: 15, weight: .medium))
                    Text("目前根据日期与标签整理记录，AI 分析尚未接入。")
                        .font(.system(size: 13)).foregroundStyle(Palette.secondary).lineSpacing(4)
                }.padding(.vertical, 5)
            } header: { Text("关于回顾") }

            if exampleCount > 0 {
                Section {
                    Button("清除示例内容", role: .destructive) { confirmingClear = true }
                        .accessibilityIdentifier("settings.clearExamples")
                } header: { Text("示例内容") } footer: {
                    Text("只移除标为“示例”的内容，你自己添加的内容会保留。")
                }
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("数据与设置").navigationBarTitleDisplayMode(.inline)
        .task { prepareExport() }
        .onChange(of: store.reviewInterval) { _, _ in prepareExport() }
        .confirmationDialog("清除示例内容？你的记录会保留。", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("清除示例内容", role: .destructive) {
                store.clearExamples()
                prepareExport()
            }
            Button("取消", role: .cancel) { }
        }
    }

    private func prepareExport() {
        do { exportURL = try store.exportFile() }
        catch {
            exportURL = nil
            store.storageError = "暂时无法准备记录备份，请稍后再试。"
        }
    }
}

private struct FocusEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var focus = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("现在最想把时间留给什么？", text: $focus, axis: .vertical)
                        .lineLimit(3...6).accessibilityIdentifier("profile.focusText")
                } header: { Text("现在，我更在意") } footer: {
                    Text("可以是一件事、一种感受，或一个想靠近的方向。以后也可以改变。")
                }
            }
            .scrollContentBackground(.hidden).pageBackground()
            .navigationTitle("此刻重视的事").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.tint(Palette.secondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.focus = focus.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }.fontWeight(.semibold).tint(Palette.coral)
                }
            }
            .onAppear { focus = store.focus }
        }.presentationDragIndicator(.visible)
    }
}

private struct ProjectEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let project: GrowthProject?
    @State private var title: String
    @State private var summary: String
    @State private var domain: LifeDomain
    @State private var nextStep: String
    @State private var progress: Double

    init(project: GrowthProject? = nil) {
        self.project = project
        _title = State(initialValue: project?.title ?? "")
        _summary = State(initialValue: project?.summary ?? "")
        _domain = State(initialValue: project?.domain ?? .career)
        _nextStep = State(initialValue: project?.nextStep ?? "")
        _progress = State(initialValue: min(max(project?.progress ?? 0, 0), 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("想投入的一件事", text: $title, axis: .vertical)
                        .lineLimit(1...3).accessibilityIdentifier("project.title")
                    TextField("为什么想做这件事？", text: $summary, axis: .vertical)
                        .lineLimit(3...6).accessibilityIdentifier("project.summary")
                    Picker("观察维度", selection: $domain) {
                        ForEach(LifeDomain.allCases) { domain in Text(domain.title).tag(domain) }
                    }.tint(Palette.sage)
                } header: { Text("给它一个方向") }
                Section {
                    TextField("小到愿意开始的一步", text: $nextStep, axis: .vertical)
                        .lineLimit(2...4).accessibilityIdentifier("project.nextStep")
                } header: { Text("下一小步") }
                Section {
                    HStack {
                        Text("当前进度")
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%")
                            .monospacedDigit().foregroundStyle(Palette.sage)
                    }
                    Slider(value: $progress, in: 0...1, step: 0.05).tint(Palette.coral)
                        .accessibilityLabel("项目进度")
                        .accessibilityValue("百分之\(Int((progress * 100).rounded()))")
                } header: { Text("按自己的节奏") } footer: { Text("这不是成绩，只是你此刻对进展的感受。") }
            }
            .scrollContentBackground(.hidden).pageBackground()
            .navigationTitle(project == nil ? "一件想投入的事" : "编辑项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.tint(Palette.secondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.semibold).tint(Palette.coral)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("project.save")
                }
            }
        }.presentationDragIndicator(.visible)
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }
        let saved = GrowthProject(id: project?.id ?? UUID(), title: cleanedTitle,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines), domain: domain,
            progress: progress, nextStep: nextStep.trimmingCharacters(in: .whitespacesAndNewlines), isDemo: project?.isDemo ?? false)
        if project == nil { store.projects.append(saved) } else { store.updateProject(saved) }
        dismiss()
    }
}

private struct QuestionEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let question: OpenQuestion?
    @State private var title: String
    @State private var note: String

    init(question: OpenQuestion? = nil) {
        self.question = question
        _title = State(initialValue: question?.title ?? "")
        _note = State(initialValue: question?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("一个想继续理解的问题", text: $title, axis: .vertical)
                        .lineLimit(2...5).accessibilityIdentifier("question.title")
                } header: { Text("我在想") }
                Section {
                    TextField("它从哪里来？你已经有哪些想法？", text: $note, axis: .vertical)
                        .lineLimit(6...12).accessibilityIdentifier("question.note")
                } header: { Text("留一点线索") } footer: { Text("不用马上找到答案。新的发现可以随时补充。") }
            }
            .scrollContentBackground(.hidden).pageBackground()
            .navigationTitle(question == nil ? "留下一个问题" : "编辑问题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.tint(Palette.secondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.semibold).tint(Palette.coral)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("question.save")
                }
            }
        }.presentationDragIndicator(.visible)
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }
        let saved = OpenQuestion(id: question?.id ?? UUID(), title: cleanedTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines), isDemo: question?.isDemo ?? false)
        if question == nil { store.questions.append(saved) } else { store.updateQuestion(saved) }
        dismiss()
    }
}

import SwiftUI

struct ProfileHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingFocusEditor = false
    @State private var showingProjectEditor = false
    @State private var showingQuestionEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                PageHeading(eyebrow: "PROFILE", title: "自我档案", subtitle: "维度、项目与待解问题。")
                focusPanel
                domainsSection
                projectsSection
                questionsSection
                NavigationLink {
                    SettingsView()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 19)).foregroundStyle(Palette.steel)
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
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("当前关注").font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "pencil").font(.system(size: 13))
                            .foregroundStyle(Palette.steel)
                    }
                    Text(store.focus.isEmpty ? "确定当前的优先事项" : store.focus)
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading).lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("编辑当前关注，\(store.focus)")
        .accessibilityIdentifier("profile.editFocus")
    }

    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "观察维度")
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
                        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func domainCount(_ domain: LifeDomain) -> String {
        let entries = store.entries(in: domain)
        if entries.isEmpty { return "暂无记录" }
        let ownCount = entries.filter { !$0.isDemo }.count
        if ownCount == 0 { return "\(entries.count) 段示例记录" }
        return "\(ownCount) 条个人记录"
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "项目进展", trailing: "添加") { showingProjectEditor = true }
                .accessibilityIdentifier("profile.projects")
            if store.projects.isEmpty {
                EmptyState(icon: "square.stack", title: "暂无项目", detail: "添加一个项目，明确目标、进度与下一步行动。")
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
            SectionHeading(title: "待解问题", trailing: "添加") { showingQuestionEditor = true }
                .accessibilityIdentifier("profile.questions")
            if store.questions.isEmpty {
                EmptyState(icon: "text.bubble", title: "暂无问题", detail: "记录需要继续观察、尚未确定答案的问题。")
            } else {
                ForEach(store.questions) { question in
                    NavigationLink { QuestionDetailView(questionID: question.id) } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: "quote.opening").font(.system(size: 17))
                                .foregroundStyle(Palette.accent).padding(.top, 3)
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
                        Text("下一步行动 · \(project.nextStep)").font(.system(size: 12))
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
                        Text(project.title).font(.system(size: 29, weight: .semibold))
                            .foregroundStyle(Palette.ink).lineSpacing(5)
                        if !project.summary.isEmpty {
                            Text(project.summary).font(.system(size: 16)).foregroundStyle(Palette.secondary).lineSpacing(7)
                        }
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            Text("项目进度").font(.subheadline).foregroundStyle(Palette.secondary)
                            Spacer()
                            Text("\(Int((min(max(project.progress, 0), 1) * 100).rounded()))%")
                                .font(.system(size: 18, weight: .medium)).monospacedDigit().foregroundStyle(project.domain.color)
                        }
                        ProgressView(value: min(max(project.progress, 0), 1)).tint(project.domain.color)
                        Text("手动更新的进度估计。")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        Label("下一步行动", systemImage: "arrow.turn.down.right")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.steel)
                        Text(project.nextStep.isEmpty ? "尚未设定下一步行动。" : project.nextStep)
                            .font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.ink).lineSpacing(6)
                    }.paperPanel()
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeading(title: "关联记录")
                        if linkedEntries.isEmpty {
                            EmptyState(icon: "text.alignleft", title: "暂无关联记录", detail: "创建记录时，可选择关联到此项目。")
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
                            Text("查看\(project.domain.title)的其他记录")
                                .font(.system(size: 14)).foregroundStyle(Palette.steel)
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 12)).foregroundStyle(Palette.steel)
                        }.padding(.vertical, 14).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }.padding(24)
            } else {
                EmptyState(icon: "archivebox", title: "项目已移除", detail: "相关记录仍然保留。")
            }
        }
        .pageBackground().navigationTitle("项目详情").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if project != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("编辑项目", systemImage: "pencil") { showingEditor = true }
                        Button("删除项目", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Palette.steel) }
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
                            Image(systemName: "quote.opening").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.accent)
                            Spacer()
                            if question.isDemo { TagPill(text: "示例") }
                        }
                        Text(question.title).font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Palette.ink).lineSpacing(8)
                        Text("保留问题，持续核对事实与判断。")
                            .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(5)
                    }
                    Divider().overlay(Palette.line)
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeading(title: "观察与线索")
                        Text(question.note.isEmpty ? "尚未添加观察或相关背景。" : question.note)
                            .font(.system(size: 17)).foregroundStyle(question.note.isEmpty ? Palette.secondary : Palette.ink)
                            .lineSpacing(9).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button { showingEditor = true } label: {
                        Label("补充观察", systemImage: "pencil")
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.steel)
                            .padding(.vertical, 13).padding(.horizontal, 18)
                            .background(Palette.steel.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }.padding(24)
            } else {
                EmptyState(icon: "text.bubble", title: "问题已移除", detail: "可返回档案添加新的问题。")
            }
        }
        .pageBackground().navigationTitle("问题详情").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if question != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("编辑问题", systemImage: "pencil") { showingEditor = true }
                        Button("删除问题", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Palette.steel) }
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
    var body: some View {
        Form {
            Section {
                Label("保存在此设备", systemImage: "iphone")
                    .font(.system(size: 15))
            } header: { Text("记录存储") } footer: {
                Text("已保存的记录和未完成的草稿均存于本机。卸载 App 会删除本机数据；可在“导入与导出”中保存记录文件。")
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("系统语音识别").font(.system(size: 15, weight: .medium))
                    Text("点击录音后请求麦克风与语音识别权限。支持的设备优先在本机转写；其他情况可能由 Apple 处理。")
                        .font(.system(size: 13)).foregroundStyle(Palette.secondary).lineSpacing(4)
                }.padding(.vertical, 5)
            } header: { Text("语音输入") }
            Section {
                Text("记录包含记录时间、维度、正文与心境。AI 分析尚未接入，可导出后自行分析。")
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary).lineSpacing(4)
            } header: { Text("关于记录") }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
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
                    TextField("当前最重要的事项或方向", text: $focus, axis: .vertical)
                        .lineLimit(3...6).accessibilityIdentifier("profile.focusText")
                } header: { Text("当前关注") } footer: {
                    Text("记录当前的优先事项，根据实际情况调整。")
                }
            }
            .scrollContentBackground(.hidden).pageBackground()
            .navigationTitle("当前关注").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.tint(Palette.secondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.focus = focus.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }.fontWeight(.semibold).tint(Palette.accent)
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
                    TextField("项目名称", text: $title, axis: .vertical)
                        .lineLimit(1...3).accessibilityIdentifier("project.title")
                    TextField("项目目标与背景", text: $summary, axis: .vertical)
                        .lineLimit(3...6).accessibilityIdentifier("project.summary")
                    Picker("观察维度", selection: $domain) {
                        ForEach(LifeDomain.allCases) { domain in Text(domain.title).tag(domain) }
                    }.tint(Palette.steel)
                } header: { Text("项目定义") }
                Section {
                    TextField("一项具体、可执行的行动", text: $nextStep, axis: .vertical)
                        .lineLimit(2...4).accessibilityIdentifier("project.nextStep")
                } header: { Text("下一步行动") }
                Section {
                    HStack {
                        Text("当前进度")
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%")
                            .monospacedDigit().foregroundStyle(Palette.steel)
                    }
                    Slider(value: $progress, in: 0...1, step: 0.05).tint(Palette.accent)
                        .accessibilityLabel("项目进度")
                        .accessibilityValue("百分之\(Int((progress * 100).rounded()))")
                } header: { Text("进展评估") } footer: { Text("进度为个人估计，可依据实际结果调整。") }
            }
            .scrollContentBackground(.hidden).pageBackground()
            .navigationTitle(project == nil ? "新建项目" : "编辑项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.tint(Palette.secondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.semibold).tint(Palette.accent)
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
                    TextField("需要继续观察的问题", text: $title, axis: .vertical)
                        .lineLimit(2...5).accessibilityIdentifier("question.title")
                } header: { Text("待解问题") }
                Section {
                    TextField("问题背景、已有观察与判断", text: $note, axis: .vertical)
                        .lineLimit(6...12).accessibilityIdentifier("question.note")
                } header: { Text("观察与线索") } footer: { Text("区分已经确认的事实与仍需验证的判断。") }
            }
            .scrollContentBackground(.hidden).pageBackground()
            .navigationTitle(question == nil ? "新建问题" : "编辑问题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.tint(Palette.secondary) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.fontWeight(.semibold).tint(Palette.accent)
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

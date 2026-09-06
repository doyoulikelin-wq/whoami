import SwiftUI

struct JournalHomeView: View {
    @EnvironmentObject var store: AppStore
    var onCompose: () -> Void

    @State private var searchText = ""
    @State private var selectedDomain: LifeDomain?
    @State private var selectedDate: Date?
    @State private var showingDateFilter = false

    private var filteredEntries: [JournalEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.sortedEntries.filter { entry in
            let matchesText = query.isEmpty
                || entry.title.localizedCaseInsensitiveContains(query)
                || entry.body.localizedCaseInsensitiveContains(query)
            let matchesDomain = selectedDomain == nil || entry.domain == selectedDomain
            let matchesDate = selectedDate.map {
                Calendar.current.isDate(entry.createdAt, inSameDayAs: $0)
            } ?? true
            return matchesText && matchesDomain && matchesDate
        }
    }

    private var entryDays: [Date] {
        Array(Set(filteredEntries.map { Calendar.current.startOfDay(for: $0.createdAt) }))
            .sorted(by: >)
    }

    private var hasFilters: Bool {
        !searchText.isEmpty || selectedDomain != nil || selectedDate != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: "MOMENTS", title: "日记", subtitle: "把普通的一天，也留在这里。")

                VStack(spacing: 15) {
                    HStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Palette.secondary)
                            TextField("搜索标题或原文", text: $searchText)
                                .font(.subheadline)
                                .submitLabel(.search)
                                .accessibilityIdentifier("journal.search")
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Palette.secondary)
                                }
                                .accessibilityLabel("清除搜索")
                            }
                        }
                        .padding(.horizontal, 15)
                        .frame(minHeight: 50)
                        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 15))

                        Button { showingDateFilter = true } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(selectedDate == nil ? Palette.ink : Palette.coral)
                                .frame(width: 50, height: 50)
                                .background(selectedDate == nil ? Palette.cream : Palette.coral.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 15))
                        }
                        .accessibilityLabel("按日期筛选日记")
                        .accessibilityIdentifier("journal.dateFilter")
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            domainFilter(nil)
                            ForEach(LifeDomain.allCases) { domain in domainFilter(domain) }
                        }
                    }

                    if let selectedDate {
                        HStack {
                            Label(DateText.format(selectedDate, "yyyy年M月d日"), systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(Palette.coral)
                            Spacer()
                            Button("全部日期") { self.selectedDate = nil }
                                .font(.subheadline)
                                .foregroundStyle(Palette.sage)
                                .frame(minHeight: 44)
                        }
                    }
                }

                if store.entries.isEmpty {
                    VStack(spacing: 8) {
                        EmptyState(icon: "book.closed", title: "从一个生活片段开始",
                                   detail: "此刻发生了什么，脑海里正在想什么？\n几句话，就可以成为第一篇日记。")
                        PrimaryButton(title: "写下第一条记录", icon: "square.and.pencil", action: onCompose)
                    }
                } else if filteredEntries.isEmpty {
                    VStack(spacing: 2) {
                        EmptyState(icon: "magnifyingglass", title: "暂时没有匹配的记录",
                                   detail: "试试其他关键词、日期或观察维度。")
                        Button("清除筛选") { clearFilters() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.coral)
                            .frame(minHeight: 44)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(hasFilters ? "找到 \(filteredEntries.count) 个片段" : "\(filteredEntries.count) 个生活片段")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.secondary)
                        Spacer()
                        let demoCount = filteredEntries.filter(\.isDemo).count
                        if demoCount > 0 {
                            Text("含 \(demoCount) 条示例")
                                .font(.caption)
                                .foregroundStyle(Palette.secondary)
                        }
                    }

                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(entryDays, id: \.self) { day in
                            daySection(day)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .sheet(isPresented: $showingDateFilter) {
            JournalDateFilterSheet(initialDate: selectedDate ?? .now) { date in
                selectedDate = date
            }
        }
    }

    private func domainFilter(_ domain: LifeDomain?) -> some View {
        let isSelected = selectedDomain == domain
        return Button { selectedDomain = domain } label: {
            Text(domain?.shortTitle ?? "全部")
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 17)
                .frame(minHeight: 44)
                .foregroundStyle(isSelected ? Color.white : Palette.secondary)
                .background(isSelected ? Palette.ink : Palette.cream, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(domain?.title ?? "全部维度")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private func daySection(_ day: Date) -> some View {
        let entries = filteredEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: day) }
        return VStack(alignment: .leading, spacing: 2) {
            NavigationLink {
                DayJournalView(date: day)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(DateText.day(day))
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text(DateText.format(day, "yyyy · EEEE"))
                        .font(.caption)
                        .foregroundStyle(Palette.secondary)
                    Spacer()
                    Text("当日日记").font(.caption)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Palette.sage)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看 \(DateText.format(day, "yyyy年M月d日")) 的全部日记")

            ForEach(entries) { entry in
                NavigationLink {
                    EntryDetailView(entryID: entry.id)
                } label: {
                    EntryRow(entry: entry)
                }
                .buttonStyle(.plain)
                if entry.id != entries.last?.id {
                    Rectangle().fill(Palette.line).frame(height: 1)
                }
            }
        }
    }

    private func clearFilters() {
        searchText = ""
        selectedDomain = nil
        selectedDate = nil
    }
}

private struct JournalDateFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    var onSelect: (Date?) -> Void

    init(initialDate: Date, onSelect: @escaping (Date?) -> Void) {
        _date = State(initialValue: initialDate)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PageHeading(eyebrow: "A DAY IN YOUR LIFE", title: "回到某一天", subtitle: "选一个日期，看看当时的自己。")
                    DatePicker("选择日期", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Palette.coral)
                    PrimaryButton(title: "查看这一天", icon: "calendar") {
                        onSelect(date)
                        dismiss()
                    }
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        Text("查看全部日期")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.sage)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(24)
            }
            .navigationTitle("日期筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .pageBackground()
        }
        .presentationDragIndicator(.visible)
    }
}

struct EntryDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var editingEntry: JournalEntry?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        Group {
            if let entry = store.entry(entryID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack(spacing: 8) {
                                TagPill(text: "原始记录", icon: "text.alignleft", filled: true)
                                if entry.isDemo {
                                    TagPill(text: "示例内容", color: Palette.secondary)
                                }
                            }
                            Text(entry.title)
                                .font(.system(size: 29, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.ink)
                                .lineSpacing(6)
                                .textSelection(.enabled)
                            Text(DateText.format(entry.createdAt, "yyyy年M月d日 EEEE · HH:mm"))
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondary)
                        }

                        HStack(spacing: 9) {
                            if let domain = entry.domain {
                                NavigationLink {
                                    DomainDetailView(domain: domain)
                                } label: {
                                    TagPill(text: domain.title, icon: domain.icon, color: domain.color)
                                }
                                .buttonStyle(.plain)
                            } else {
                                TagPill(text: "暂未分类", color: Palette.secondary)
                            }
                            if let mood = entry.mood {
                                TagPill(text: mood.title, icon: mood.icon, color: Palette.secondary)
                            }
                        }

                        Rectangle().fill(Palette.line).frame(height: 1)

                        Text(entry.body)
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.ink)
                            .lineSpacing(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        if let projectID = entry.projectID,
                           let project = store.projects.first(where: { $0.id == projectID }) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("关联项目")
                                    .font(.caption)
                                    .foregroundStyle(Palette.secondary)
                                Label(project.title, systemImage: "briefcase")
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.sage)
                            }
                            .padding(.top, 9)
                        }

                        NavigationLink {
                            DayJournalView(date: entry.createdAt)
                        } label: {
                            HStack {
                                Label("回看这一天", systemImage: "calendar")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.sage)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 14)
                    }
                    .padding(24)
                }
            } else {
                EmptyState(icon: "doc", title: "这条记录已不在这里", detail: "记录可能已被删除。返回日记，查看其他片段。")
            }
        }
        .navigationTitle("生活片段")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let entry = store.entry(entryID) {
                    Button("编辑") { editingEntry = entry }
                        .foregroundStyle(Palette.coral)
                        .accessibilityIdentifier("journal.edit")
                    Menu {
                        Button("删除记录", role: .destructive) { showingDeleteConfirmation = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(minWidth: 36, minHeight: 44)
                    }
                    .accessibilityLabel("记录操作")
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditJournalEntrySheet(entry: entry)
        }
        .confirmationDialog("删除这条记录？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                store.deleteEntry(entryID)
                dismiss()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("这条记录将从本机删除，此操作无法撤销。")
        }
    }
}

private struct EditJournalEntrySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalEntry

    init(entry: JournalEntry) {
        _draft = State(initialValue: entry)
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("给这段经历一个标题", text: $draft.title, axis: .vertical)
                        .lineLimit(1...4)
                        .accessibilityIdentifier("journal.edit.title")
                }
                Section("原文") {
                    TextEditor(text: $draft.body)
                        .frame(minHeight: 220)
                        .lineSpacing(6)
                        .accessibilityLabel("编辑记录原文")
                        .accessibilityIdentifier("journal.edit.body")
                }
                Section("观察维度") {
                    Picker("维度", selection: $draft.domain) {
                        Text("暂不分类").tag(Optional<LifeDomain>.none)
                        ForEach(LifeDomain.allCases) { domain in
                            Text(domain.title).tag(Optional(domain))
                        }
                    }
                }
                Section("心情与项目 · 选填") {
                    Picker("心情", selection: $draft.mood) {
                        Text("暂不记录").tag(Optional<Mood>.none)
                        ForEach(Mood.allCases) { mood in
                            Text(mood.title).tag(Optional(mood))
                        }
                    }
                    Picker("关联项目", selection: $draft.projectID) {
                        Text("不关联项目").tag(Optional<UUID>.none)
                        ForEach(store.projects) { project in
                            Text(project.title + (project.isDemo ? " · 示例" : "")).tag(Optional(project.id))
                        }
                    }
                }
                Section {
                    HStack {
                        Text("记录时间")
                        Spacer()
                        Text(DateText.format(draft.createdAt, "yyyy/M/d HH:mm"))
                            .foregroundStyle(Palette.secondary)
                    }
                    if draft.isDemo {
                        Label("这是示例记录，修改后仍保留示例标记。", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondary)
                    }
                } footer: {
                    Text("点击保存后才会更新记录。取消会保留原来的内容。")
                }
            }
            .scrollContentBackground(.hidden)
            .pageBackground()
            .navigationTitle("编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.update(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("journal.edit.save")
                }
            }
            .tint(Palette.coral)
        }
    }
}

struct DayJournalView: View {
    @EnvironmentObject var store: AppStore
    let date: Date
    @State private var displayMode = 0

    private var entries: [JournalEntry] {
        store.sortedEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: "DAILY JOURNAL", title: DateText.format(date, "M月d日，EEEE"),
                            subtitle: "\(DateText.format(date, "yyyy年")) · \(entries.count) 个生活片段")

                Picker("日记阅读方式", selection: $displayMode) {
                    Text("原始记录").tag(0)
                    Text("按时间整理").tag(1)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("journal.day.mode")

                if entries.isEmpty {
                    EmptyState(icon: "calendar", title: "这一天还没有记录", detail: "没有留下的部分，先保留为空白。")
                } else if displayMode == 0 {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("最近记录在前 · 点击可查看和编辑原文")
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                            .padding(.bottom, 8)
                        ForEach(entries) { entry in
                            NavigationLink {
                                EntryDetailView(entryID: entry.id)
                            } label: {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            if entry.id != entries.last?.id {
                                Rectangle().fill(Palette.line).frame(height: 1)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        TagPill(text: "本地整理", icon: "text.alignleft", filled: true)
                        Text("按记录时间从早到晚排列，保留原文。尚未调用 AI，也未补写经历。")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondary)
                            .lineSpacing(5)
                    }

                    VStack(alignment: .leading, spacing: 30) {
                        ForEach(entries.reversed()) { entry in
                            VStack(alignment: .leading, spacing: 13) {
                                HStack(spacing: 8) {
                                    Text(DateText.format(entry.createdAt, "HH:mm"))
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Palette.sage)
                                    if let domain = entry.domain {
                                        Text("· \(domain.shortTitle)")
                                            .font(.caption)
                                            .foregroundStyle(Palette.secondary)
                                    }
                                    if entry.isDemo {
                                        Text("示例")
                                            .font(.caption)
                                            .foregroundStyle(Palette.secondary)
                                    }
                                }
                                Text(entry.title)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text(entry.body)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Palette.ink)
                                    .lineSpacing(8)
                                    .textSelection(.enabled)
                                NavigationLink {
                                    EntryDetailView(entryID: entry.id)
                                } label: {
                                    Label("查看原始记录", systemImage: "arrow.up.right")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Palette.sage)
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(.plain)
                                Rectangle().fill(Palette.line).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("当日日记")
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
    }
}

struct DomainDetailView: View {
    @EnvironmentObject var store: AppStore
    let domain: LifeDomain

    private var entries: [JournalEntry] { store.entries(in: domain) }
    private var projects: [GrowthProject] { store.projects.filter { $0.domain == domain } }

    private var prompt: String {
        switch domain {
        case .career: "正在推进什么，留下了什么成果，又卡在了哪里？"
        case .finance: "看清拥有的资源、承担的压力和可以做出的选择。"
        case .body: "睡眠、活动和精力，怎样影响着你的每一天？"
        case .emotion: "留意情绪出现的情境，以及后来发生的变化。"
        case .learning: "留下问题、理解和那些被新经历改变的判断。"
        case .relationships: "如何表达需要、建立连接，也照顾自己的边界。"
        case .life: "时间花在哪里，生活是否接近你真正重视的事？"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                DomainIcon(domain: domain, size: 58)
                PageHeading(eyebrow: "A PART OF YOU", title: domain.title, subtitle: prompt)

                HStack(spacing: 12) {
                    TagPill(text: "\(entries.filter { !$0.isDemo }.count) 条真实记录", color: domain.color, filled: true)
                    if entries.contains(where: \.isDemo) {
                        Text("另有 \(entries.filter(\.isDemo).count) 条示例")
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                    }
                }

                if !projects.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeading(title: "正在培养的事")
                        ForEach(projects) { project in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(project.title)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(Palette.ink)
                                    if project.isDemo {
                                        Text("示例").font(.caption).foregroundStyle(Palette.secondary)
                                    }
                                }
                                Text(project.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.secondary)
                                    .lineSpacing(4)
                                ProgressView(value: min(max(project.progress, 0), 1))
                                    .tint(domain.color)
                                    .accessibilityLabel("\(project.title)的进度")
                                Text("下一步 · \(project.nextStep)")
                                    .font(.caption)
                                    .foregroundStyle(Palette.sage)
                                    .lineSpacing(4)
                            }
                            if project.id != projects.last?.id {
                                Rectangle().fill(Palette.line).frame(height: 1)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeading(title: "与此有关的片段")
                    if entries.isEmpty {
                        EmptyState(icon: domain.icon, title: "这一面，还等待被记录", detail: "记录时选择“\(domain.title)”，相关经历就会出现在这里。")
                    } else {
                        ForEach(entries) { entry in
                            NavigationLink {
                                EntryDetailView(entryID: entry.id)
                            } label: {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            if entry.id != entries.last?.id {
                                Rectangle().fill(Palette.line).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(domain.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .pageBackground()
    }
}

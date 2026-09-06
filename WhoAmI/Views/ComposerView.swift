import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var choosingContext = false
    @State private var choosingMood = false

    private var isEmpty: Bool { store.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(DateText.format(.now, "M月d日 EEEE"))
                    Spacer()
                    Label("草稿自动保留", systemImage: "checkmark.circle")
                }.font(.system(size: 11)).foregroundStyle(Palette.secondary)

                Text("此刻，想记下什么？")
                    .font(.system(size: 25, weight: .semibold)).foregroundStyle(Palette.ink)

                ZStack(alignment: .topLeading) {
                    if store.draftText.isEmpty {
                        Text("发生的事、冒出的想法，\n或一个说不清的感受……")
                            .font(.system(size: 17)).foregroundStyle(Palette.secondary.opacity(0.75))
                            .lineSpacing(8).padding(.top, 9).padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $store.draftText)
                        .font(.system(size: 17)).lineSpacing(8).foregroundStyle(Palette.ink)
                        .scrollContentBackground(.hidden).focused($focused)
                        .frame(minHeight: 160)
                        .accessibilityLabel("记录正文").accessibilityIdentifier("entry-body-input")
                }

                HStack(spacing: 9) {
                    Button { focused = false; choosingContext = true } label: {
                        TagPill(text: store.draftDomain?.shortTitle ?? "加个分类", icon: store.draftDomain?.icon ?? "tag", filled: store.draftDomain != nil)
                            .frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityIdentifier("choose-domain")
                    Button { focused = false; choosingMood = true } label: {
                        TagPill(text: store.draftMood?.title ?? "记下心情", icon: store.draftMood?.icon ?? "leaf", filled: store.draftMood != nil)
                            .frame(minHeight: 44)
                    }.buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                if let projectID = store.draftProjectID, let project = store.projects.first(where: { $0.id == projectID }) {
                    Label(project.title, systemImage: "folder").font(.caption).foregroundStyle(Palette.sage)
                }
                Text("分类和心情都可以以后再补。")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
            .pageBackground().navigationTitle("记一下").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("收起") { dismiss() }.foregroundStyle(Palette.secondary)
                        .accessibilityIdentifier("dismiss-composer")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard store.saveDraft() != nil else { return }
                        dismiss()
                    }.fontWeight(.semibold).disabled(isEmpty).accessibilityIdentifier("save-entry")
                }
            }
            .sheet(isPresented: $choosingContext) { contextPicker }
            .sheet(isPresented: $choosingMood) { moodPicker }
            .task { focused = true }
        }.presentationDragIndicator(.visible)
    }

    private var contextPicker: some View {
        NavigationStack {
            Form {
                Section("观察维度 · 选填") {
                    Button {
                        store.draftDomain = nil
                    } label: { selectionRow("暂不分类", icon: "text.alignleft", selected: store.draftDomain == nil) }
                    ForEach(LifeDomain.allCases) { domain in
                        Button { store.draftDomain = domain } label: {
                            selectionRow(domain.title, icon: domain.icon, selected: store.draftDomain == domain)
                        }
                    }
                }
                if !store.projects.isEmpty {
                    Section("关联项目 · 选填") {
                        Button { store.draftProjectID = nil } label: { selectionRow("不关联项目", icon: "folder", selected: store.draftProjectID == nil) }
                        ForEach(store.projects) { project in
                            Button { store.draftProjectID = project.id } label: {
                                selectionRow(project.title + (project.isDemo ? " · 示例" : ""), icon: "folder", selected: store.draftProjectID == project.id)
                            }
                        }
                    }
                }
            }.scrollContentBackground(.hidden).pageBackground()
                .navigationTitle("添加关联").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { choosingContext = false; focused = true } } }
        }
    }

    private var moodPicker: some View {
        NavigationStack {
            List {
                Button { store.draftMood = nil; choosingMood = false } label: { selectionRow("暂不记录", icon: "minus", selected: store.draftMood == nil) }
                ForEach(Mood.allCases) { mood in
                    Button { store.draftMood = mood; choosingMood = false } label: { selectionRow(mood.title, icon: mood.icon, selected: store.draftMood == mood) }
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("此刻的心情").navigationBarTitleDisplayMode(.inline)
        }.presentationDetents([.medium])
    }

    private func selectionRow(_ title: String, icon: String, selected: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(Palette.ink)
            Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(Palette.coral) }
        }.frame(minHeight: 30).contentShape(Rectangle())
    }
}

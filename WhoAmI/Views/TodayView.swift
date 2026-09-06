import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    var onCompose: () -> Void
    var onJournal: () -> Void
    @State private var editingState = false
    @State private var waving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "W H O A M I", title: "今天，慢慢来。", subtitle: DateText.format(.now, "M月d日 EEEE"))

                companion

                PrimaryButton(title: store.draftText.isEmpty ? "记一下" : "继续写草稿", action: onCompose)
                    .accessibilityIdentifier("compose-primary")

                VStack(alignment: .leading, spacing: 9) {
                    SectionHeading(title: "此刻的状态", trailing: store.mood == nil ? "记录" : "更新", action: { editingState = true })
                    Button { editingState = true } label: {
                        HStack(spacing: 10) {
                            TagPill(text: store.mood?.title ?? "心情如何", icon: store.mood?.icon ?? "leaf")
                            TagPill(text: store.mood == nil ? "精力如何" : store.energyLabel, icon: "bolt", color: Palette.sage)
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("update-state")
                }

                VStack(spacing: 0) {
                    SectionHeading(title: "最近的记录", trailing: "全部", action: onJournal)
                    if store.entries.isEmpty {
                        EmptyState(icon: "pencil.and.outline", title: "从一个真实的片段开始", detail: "想到了什么，发生了什么。\n一句话也可以。")
                    } else {
                        ForEach(Array(store.sortedEntries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                            NavigationLink { EntryDetailView(entryID: entry.id) } label: { EntryRow(entry: entry) }
                                .buttonStyle(.plain)
                            if index < min(store.entries.count, 3) - 1 { Divider().overlay(Palette.line) }
                        }
                    }
                }

                if let review = store.reviews.first(where: { !$0.actionDone }) {
                    NavigationLink { ReviewDetailView(reviewID: review.id) } label: {
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: "arrow.turn.down.right").foregroundStyle(Palette.coral)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(review.isDemo ? "下一小步 · 示例" : "下一小步").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text(review.action).font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(4).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.secondary)
                        }.padding(18).background(Palette.cream, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }

                if store.hasExamples {
                    Label("正在浏览示例，你的记录会单独保留", systemImage: "circle.dotted")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 2)
                }
            }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .pageBackground()
        .sheet(isPresented: $editingState) { StateEditorView() }
    }

    private var companion: some View {
        ZStack(alignment: .leading) {
            Image("Companion").resizable().scaledToFill()
                .frame(height: 180).clipped()
                .scaleEffect(waving && !reduceMotion ? 1.025 : 1, anchor: .bottomTrailing)
            VStack(alignment: .leading, spacing: 12) {
                Text(waving ? "今天也在，\n好好陪着你。" : "把今天的自己，\n好好记下来。")
                    .font(.system(size: 21, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.ink).lineSpacing(6)
                Text("每一点真实，都值得被看见")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }.padding(.leading, 17).padding(.bottom, 10)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) { waving.toggle() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("陪伴角色。把今天的自己，好好记下来。")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { waving.toggle() }
    }
}

struct StateEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var mood: Mood = .calm
    @State private var energy = 3.0
    @State private var saveAsEntry = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("先停一下，感受此刻。")
                        .font(.system(size: 25, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text("没有好坏，记录真实的状态就好。")
                        .font(.subheadline).foregroundStyle(Palette.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("现在的心情").font(.headline)
                        HStack(spacing: 8) {
                            ForEach(Mood.allCases) { item in
                                Button { mood = item } label: {
                                    VStack(spacing: 10) {
                                        Image(systemName: item.icon).font(.system(size: 23, weight: .light))
                                        Text(item.title).font(.system(size: 13))
                                    }.frame(maxWidth: .infinity).frame(height: 80)
                                        .foregroundStyle(mood == item ? Palette.coral : Palette.secondary)
                                        .background(mood == item ? Palette.coral.opacity(0.09) : Palette.paper,
                                                    in: RoundedRectangle(cornerRadius: 16))
                                }.buttonStyle(.plain).accessibilityAddTraits(mood == item ? .isSelected : [])
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 17) {
                        HStack { Text("精力").font(.headline); Spacer(); Text("\(Int(energy)) / 5").foregroundStyle(Palette.sage) }
                        Slider(value: $energy, in: 1...5, step: 1).accessibilityLabel("精力")
                        HStack { Text("需要休息"); Spacer(); Text("充满活力") }.font(.caption).foregroundStyle(Palette.secondary)
                    }.paperPanel()
                    Toggle("同时留在今天的日记里", isOn: $saveAsEntry).font(.subheadline)
                    PrimaryButton(title: "保存此刻", icon: "checkmark") {
                        store.mood = mood; store.energy = Int(energy)
                        if saveAsEntry {
                            store.entries.append(JournalEntry(title: "此刻的状态 · \(mood.title)",
                                body: "心情：\(mood.title)\n精力：\(Int(energy)) / 5\n这是一条我主动记录的状态。",
                                createdAt: .now, domain: .emotion, mood: mood))
                        }
                        dismiss()
                    }.accessibilityIdentifier("save-state")
                }.padding(24)
            }.pageBackground().navigationTitle("此刻的状态").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
                .onAppear { mood = store.mood ?? .calm; energy = Double(store.energy) }
        }.presentationDragIndicator(.visible)
    }
}

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    var onCompose: () -> Void
    var onJournal: () -> Void
    @State private var editingState = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "WHOAMI", title: "观察自己", subtitle: DateText.format(.now, "M月d日 EEEE"))

                observation

                PrimaryButton(title: store.draftText.isEmpty ? "新增记录" : "继续草稿", action: onCompose)
                    .accessibilityIdentifier("compose-primary")

                VStack(alignment: .leading, spacing: 9) {
                    SectionHeading(title: "当前状态", trailing: store.mood == nil ? "记录" : "更新", action: { editingState = true })
                    Button { editingState = true } label: {
                        HStack(spacing: 10) {
                            TagPill(text: store.mood?.title ?? "心情未记录", icon: store.mood?.icon ?? "leaf")
                            TagPill(text: store.mood == nil ? "精力未记录" : store.energyLabel, icon: "bolt", color: Palette.steel)
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("update-state")
                }

                VStack(spacing: 0) {
                    SectionHeading(title: "最近记录", trailing: "全部", action: onJournal)
                    if store.entries.isEmpty {
                        EmptyState(icon: "pencil.and.outline", title: "暂无记录", detail: "记录事件、反应与当时的判断。")
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
                            Image(systemName: "arrow.turn.down.right").foregroundStyle(Palette.accent)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(review.isDemo ? "下一步行动 · 示例" : "下一步行动").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text(review.action).font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(4).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.secondary)
                        }.padding(18).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }

                if store.hasExamples {
                    Label("示例数据 · 与个人记录分开保存", systemImage: "circle.dotted")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 2)
                }
            }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .pageBackground()
        .sheet(isPresented: $editingState) { StateEditorView() }
    }

    private var observation: some View {
        ZStack(alignment: .leading) {
            Image("Companion").resizable().scaledToFill()
                .frame(height: 180).clipped()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                Text("记录事实。\n检视判断。")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(Palette.ink).lineSpacing(7)
                Text("把情绪、行动和结果分开看。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }.padding(.leading, 18)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line.opacity(0.6), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
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
                    Text("记录当前状态")
                        .font(.system(size: 25, weight: .semibold)).foregroundStyle(Palette.ink)
                    Text("以此刻的感受为准。")
                        .font(.subheadline).foregroundStyle(Palette.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("心情").font(.headline)
                        HStack(spacing: 8) {
                            ForEach(Mood.allCases) { item in
                                Button { mood = item } label: {
                                    VStack(spacing: 10) {
                                        Image(systemName: item.icon).font(.system(size: 23, weight: .light))
                                        Text(item.title).font(.system(size: 13))
                                    }.frame(maxWidth: .infinity).frame(height: 80)
                                        .foregroundStyle(mood == item ? Palette.accent : Palette.secondary)
                                        .background(mood == item ? Palette.accent.opacity(0.09) : Palette.paper,
                                                    in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain).accessibilityAddTraits(mood == item ? .isSelected : [])
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 17) {
                        HStack { Text("精力").font(.headline); Spacer(); Text("\(Int(energy)) / 5").foregroundStyle(Palette.steel) }
                        Slider(value: $energy, in: 1...5, step: 1).accessibilityLabel("精力")
                        HStack { Text("精力较低"); Spacer(); Text("精力充足") }.font(.caption).foregroundStyle(Palette.secondary)
                    }.paperPanel()
                    Toggle("同时保存为日记记录", isOn: $saveAsEntry).font(.subheadline)
                    PrimaryButton(title: "保存状态", icon: "checkmark") {
                        store.mood = mood; store.energy = Int(energy)
                        if saveAsEntry {
                            store.entries.append(JournalEntry(title: "状态记录 · \(mood.title)",
                                body: "心情：\(mood.title)\n精力：\(Int(energy)) / 5",
                                createdAt: .now, domain: .emotion, mood: mood))
                        }
                        dismiss()
                    }.accessibilityIdentifier("save-state")
                }.padding(24)
            }.pageBackground().navigationTitle("当前状态").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
                .onAppear { mood = store.mood ?? .calm; energy = Double(store.energy) }
        }.presentationDragIndicator(.visible)
    }
}

import SwiftUI

struct ReviewHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var createdReviewID: UUID?
    @State private var showingCreatedReview = false

    private var sortedReviews: [ReviewReport] {
        store.reviews.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeading(eyebrow: "REFLECTION", title: "换个角度，看自己。",
                            subtitle: "每一次回看，都是一次新的认识。")

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Label("回顾周期", systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text("由你决定节奏")
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                    Picker("回顾周期", selection: $store.reviewInterval) {
                        ForEach([2, 3, 4], id: \.self) { days in
                            Text("\(days) 天").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("review.interval")
                    Text("每次回看最近 \(store.reviewInterval) 天，随时可以手动开始。")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
                .paperPanel()

                VStack(alignment: .leading, spacing: 12) {
                    PrimaryButton(title: "回看这几天", icon: "text.alignleft") {
                        let review = store.createLocalReview()
                        createdReviewID = review.id
                        showingCreatedReview = true
                    }
                    .accessibilityIdentifier("review.createLocal")
                    Text("按日期与分类整理原文。AI 分析尚未接入，示例不会参与回顾。")
                        .font(.caption).foregroundStyle(Palette.secondary)
                        .lineSpacing(4).padding(.horizontal, 3)
                }

                if let latest = sortedReviews.first {
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeading(title: "最近一次回看")
                        NavigationLink {
                            ReviewDetailView(reviewID: latest.id)
                        } label: {
                            latestCard(latest)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("review.latest")
                    }
                } else {
                    EmptyState(icon: "text.book.closed", title: "从一次回看开始",
                               detail: "把这几天的记录放在一起，\n看看发生了什么，下一步想做什么。")
                        .paperPanel()
                }

                if sortedReviews.count > 1 {
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeading(title: "之前的回看")
                        VStack(spacing: 0) {
                            ForEach(Array(sortedReviews.dropFirst())) { review in
                                NavigationLink {
                                    ReviewDetailView(reviewID: review.id)
                                } label: {
                                    historyRow(review)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("review.history.\(review.id.uuidString)")
                                if review.id != sortedReviews.last?.id {
                                    Divider().overlay(Palette.line)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22))
                    }
                }
            }
            .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationDestination(isPresented: $showingCreatedReview) {
            if let createdReviewID {
                ReviewDetailView(reviewID: createdReviewID)
            }
        }
    }

    private func latestCard(_ review: ReviewReport) -> some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(alignment: .center) {
                ReviewOriginPill(review: review)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.sage)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(DateText.range(review.periodStart, review.periodEnd))
                    .font(.caption).foregroundStyle(Palette.secondary)
                Text("这几天的你")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }
            VStack(alignment: .leading, spacing: 17) {
                ReviewPreviewRow(number: "01", title: "发生了什么", text: review.summary)
                ReviewPreviewRow(number: "02", title: "值得留意的变化", text: review.observation)
                ReviewPreviewRow(number: "03", title: "接下来的一小步", text: review.action)
            }
            Divider().overlay(Palette.line)
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                Text("\(review.entryIDs.count) 条原始记录")
                Spacer()
                Text("打开回顾")
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
            }
            .font(.caption).foregroundStyle(Palette.sage)
        }
        .paperPanel()
    }

    private func historyRow(_ review: ReviewReport) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text(DateText.range(review.periodStart, review.periodEnd))
                    .font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                Text(review.summary)
                    .font(.caption).foregroundStyle(Palette.secondary)
                    .lineLimit(2).lineSpacing(3)
                HStack(spacing: 8) {
                    Text(review.isDemo ? "复盘示例" : review.isLocal ? "本地回顾" : "复盘")
                    if review.actionDone {
                        Label("行动已完成", systemImage: "checkmark.circle")
                    }
                }
                .font(.system(size: 11)).foregroundStyle(Palette.sage)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundStyle(Palette.secondary)
        }
        .padding(.vertical, 18).contentShape(Rectangle())
    }
}

struct ReviewDetailView: View {
    @EnvironmentObject private var store: AppStore
    let reviewID: UUID
    @State private var actionDraft = ""
    @State private var feedbackDraft = ""
    @State private var actionDone = false
    @State private var loadedReviewID: UUID?
    @State private var didSave = false
    @FocusState private var focusedField: EditableField?

    private enum EditableField: Hashable {
        case action, feedback
    }

    private var report: ReviewReport? {
        store.reviews.first { $0.id == reviewID }
    }

    var body: some View {
        ScrollView {
            if let report {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 14) {
                        ReviewOriginPill(review: report)
                        PageHeading(eyebrow: "A MOMENT TO REFLECT", title: "这几天的你",
                                    subtitle: DateText.range(report.periodStart, report.periodEnd))
                        Text(originExplanation(report))
                            .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(4)
                    }

                    reportSection(number: "01", title: "发生了什么", content: report.summary)
                    reportSection(number: "02", title: "值得留意的变化", content: report.observation)
                    reportSection(number: "03", title: report.isLocal ? "整理方式与信息边界" : "待验证的解释",
                                  content: report.hypothesis)

                    evidenceSection(report)

                    VStack(alignment: .leading, spacing: 17) {
                        SectionHeading(title: "接下来的一小步")
                        Text("可以修改成你愿意尝试的行动。")
                            .font(.caption).foregroundStyle(Palette.secondary)
                        TextField("写下一个具体的小行动", text: $actionDraft, axis: .vertical)
                            .font(.body).foregroundStyle(Palette.ink)
                            .lineLimit(3...7).padding(14)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: 14))
                            .focused($focusedField, equals: .action)
                            .accessibilityIdentifier("review.action")
                        Toggle("这一步已经做了", isOn: $actionDone)
                            .font(.subheadline).tint(Palette.sage)
                            .accessibilityIdentifier("review.actionDone")
                        Divider().overlay(Palette.line)
                        Text("补充与不同看法")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text("补充遗漏的背景，或写下你不同意的地方。")
                            .font(.caption).foregroundStyle(Palette.secondary)
                        TextField("我的补充……", text: $feedbackDraft, axis: .vertical)
                            .font(.body).foregroundStyle(Palette.ink)
                            .lineLimit(3...8).padding(14)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: 14))
                            .focused($focusedField, equals: .feedback)
                            .accessibilityIdentifier("review.feedback")
                        PrimaryButton(title: "保存行动与反馈", icon: "checkmark") {
                            saveEdits()
                        }
                        .accessibilityIdentifier("review.save")
                        if didSave {
                            Label("已保存在本机", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(Palette.sage)
                                .accessibilityIdentifier("review.saved")
                        }
                        if let error = store.storageError {
                            Text(error).font(.caption).foregroundStyle(Palette.coral)
                        }
                    }
                    .paperPanel()
                }
                .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 32)
            } else {
                EmptyState(icon: "doc.text", title: "这份回顾已不在这里",
                           detail: "它可能已被删除。返回后可以整理一份新的本地回顾。")
                    .padding(.horizontal, 22)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .navigationTitle(report?.isDemo == true ? "复盘示例" : "回顾详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadEditsIfNeeded() }
        .onChange(of: actionDraft) { didSave = false }
        .onChange(of: feedbackDraft) { didSave = false }
        .onChange(of: actionDone) { didSave = false }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
            }
        }
    }

    private func reportSection(number: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(number).font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.coral)
                Text(title).font(.headline).foregroundStyle(Palette.ink)
            }
            Text(content).font(.body).foregroundStyle(Palette.ink)
                .lineSpacing(7).textSelection(.enabled)
        }
        .paperPanel()
    }

    private func evidenceSection(_ report: ReviewReport) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                SectionHeading(title: "回到原始记录")
                Text("\(report.entryIDs.filter { store.entry($0) != nil }.count) / \(report.entryIDs.count)")
                    .font(.caption).foregroundStyle(Palette.secondary)
                    .fixedSize()
                    .accessibilityLabel("\(report.entryIDs.count) 条依据中有 \(report.entryIDs.filter { store.entry($0) != nil }.count) 条可以查看")
            }
            if report.entryIDs.isEmpty {
                Text("这次回顾还没有关联原文。留下一个真实片段后，可以重新整理。")
                    .font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(5)
                    .padding(.vertical, 10)
            } else {
                ForEach(report.entryIDs, id: \.self) { entryID in
                    if let entry = store.entry(entryID) {
                        NavigationLink {
                            EntryDetailView(entryID: entryID)
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("review.evidence.\(entryID.uuidString)")
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(Palette.secondary).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("原始记录已删除").font(.subheadline.weight(.medium))
                                Text("暂时无法核对与这条记录相关的内容。")
                                    .font(.caption).lineSpacing(3)
                            }
                            .foregroundStyle(Palette.secondary)
                        }
                        .padding(.vertical, 15)
                        .accessibilityIdentifier("review.evidenceMissing")
                    }
                    if entryID != report.entryIDs.last {
                        Divider().overlay(Palette.line)
                    }
                }
            }
        }
        .paperPanel()
    }

    private func originExplanation(_ report: ReviewReport) -> String {
        if report.isDemo {
            return "以下是虚构的复盘示例，用来展示回看方式，不代表你的真实经历。"
        }
        if report.isLocal {
            return "这是按日期和标签整理的本地回顾，尚未使用 AI 分析，不推断动机或长期状态。"
        }
        return "回顾依据列在下方，可以打开原文、补充背景或提出不同看法。"
    }

    private func loadEditsIfNeeded() {
        guard let report, loadedReviewID != report.id else { return }
        actionDraft = report.action
        feedbackDraft = report.feedback
        actionDone = report.actionDone
        loadedReviewID = report.id
    }

    private func saveEdits() {
        guard var updated = report else { return }
        updated.action = actionDraft
        updated.feedback = feedbackDraft
        updated.actionDone = actionDone
        store.updateReview(updated)
        focusedField = nil
        didSave = store.storageError == nil
    }
}

private struct ReviewOriginPill: View {
    let review: ReviewReport
    var body: some View {
        TagPill(text: review.isDemo ? "复盘示例" : review.isLocal ? "本地回顾" : "复盘",
                icon: review.isDemo ? "book.closed" : "doc.text",
                color: review.isDemo ? Palette.coral : Palette.sage, filled: true)
    }
}

private struct ReviewPreviewRow: View {
    let number: String
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.coral).padding(.top, 2)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                Text(text).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    .lineSpacing(4).lineLimit(2)
            }
        }
    }
}

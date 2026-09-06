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
                PageHeading(eyebrow: "REVIEW", title: "检视变化",
                            subtitle: "依据记录，核对判断。")

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Label("回顾周期", systemImage: "calendar")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text("按周期整理")
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                    Picker("回顾周期", selection: $store.reviewInterval) {
                        ForEach([2, 3, 4], id: \.self) { days in
                            Text("\(days) 天").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("review.interval")
                    Text("覆盖最近 \(store.reviewInterval) 天，可随时手动生成。")
                        .font(.caption).foregroundStyle(Palette.secondary)
                }
                .paperPanel()

                VStack(alignment: .leading, spacing: 12) {
                    PrimaryButton(title: "生成回顾", icon: "text.alignleft") {
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
                        SectionHeading(title: "最近回顾")
                        NavigationLink {
                            ReviewDetailView(reviewID: latest.id)
                        } label: {
                            latestCard(latest)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("review.latest")
                    }
                } else {
                    EmptyState(icon: "text.book.closed", title: "暂无回顾",
                               detail: "汇总最近几天的记录，\n核对变化并确定下一步行动。")
                        .paperPanel()
                }

                if sortedReviews.count > 1 {
                    VStack(alignment: .leading, spacing: 15) {
                        SectionHeading(title: "历史回顾")
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
                        .background(Palette.paper, in: RoundedRectangle(cornerRadius: 12))
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
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.steel)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(DateText.range(review.periodStart, review.periodEnd))
                    .font(.caption).foregroundStyle(Palette.secondary)
                Text("阶段观察")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
            VStack(alignment: .leading, spacing: 17) {
                ReviewPreviewRow(number: "01", title: "记录概况", text: review.summary)
                ReviewPreviewRow(number: "02", title: "变化线索", text: review.observation)
                ReviewPreviewRow(number: "03", title: "下一步行动", text: review.action)
            }
            Divider().overlay(Palette.line)
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                Text("\(review.entryIDs.count) 条原始记录")
                Spacer()
                Text("打开回顾")
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
            }
            .font(.caption).foregroundStyle(Palette.steel)
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
                .font(.system(size: 11)).foregroundStyle(Palette.steel)
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
                        PageHeading(eyebrow: "REVIEW", title: "阶段检视",
                                    subtitle: DateText.range(report.periodStart, report.periodEnd))
                        Text(originExplanation(report))
                            .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(4)
                    }

                    reportSection(number: "01", title: "记录概况", content: report.summary)
                    reportSection(number: "02", title: "变化线索", content: report.observation)
                    reportSection(number: "03", title: report.isLocal ? "整理方式与信息边界" : "待验证的解释",
                                  content: report.hypothesis)

                    evidenceSection(report)

                    VStack(alignment: .leading, spacing: 17) {
                        SectionHeading(title: "下一步行动")
                        Text("确定一项具体、可验证的行动。")
                            .font(.caption).foregroundStyle(Palette.secondary)
                        TextField("记录下一步行动", text: $actionDraft, axis: .vertical)
                            .font(.body).foregroundStyle(Palette.ink)
                            .lineLimit(3...7).padding(14)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: 10))
                            .focused($focusedField, equals: .action)
                            .accessibilityIdentifier("review.action")
                        Toggle("行动已完成", isOn: $actionDone)
                            .font(.subheadline).tint(Palette.steel)
                            .accessibilityIdentifier("review.actionDone")
                        Divider().overlay(Palette.line)
                        Text("补充与修正")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text("补充背景，标明不同意或尚待验证的判断。")
                            .font(.caption).foregroundStyle(Palette.secondary)
                        TextField("补充事实或修正判断", text: $feedbackDraft, axis: .vertical)
                            .font(.body).foregroundStyle(Palette.ink)
                            .lineLimit(3...8).padding(14)
                            .background(Palette.background, in: RoundedRectangle(cornerRadius: 10))
                            .focused($focusedField, equals: .feedback)
                            .accessibilityIdentifier("review.feedback")
                        PrimaryButton(title: "保存行动与反馈", icon: "checkmark") {
                            saveEdits()
                        }
                        .accessibilityIdentifier("review.save")
                        if didSave {
                            Label("已保存在本机", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(Palette.steel)
                                .accessibilityIdentifier("review.saved")
                        }
                        if let error = store.storageError {
                            Text(error).font(.caption).foregroundStyle(Palette.accent)
                        }
                    }
                    .paperPanel()
                }
                .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 32)
            } else {
                EmptyState(icon: "doc.text", title: "回顾不存在",
                           detail: "该回顾可能已删除。返回后可重新生成。")
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
                    .foregroundStyle(Palette.accent)
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
                SectionHeading(title: "原始依据")
                Text("\(report.entryIDs.filter { store.entry($0) != nil }.count) / \(report.entryIDs.count)")
                    .font(.caption).foregroundStyle(Palette.secondary)
                    .fixedSize()
                    .accessibilityLabel("\(report.entryIDs.count) 条依据中有 \(report.entryIDs.filter { store.entry($0) != nil }.count) 条可以查看")
            }
            if report.entryIDs.isEmpty {
                Text("本次回顾没有关联原文。添加记录后可重新生成。")
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
                                Text("无法核对该记录对应的内容。")
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
            return "以下为虚构的复盘示例，仅展示检视结构，不代表你的真实经历。"
        }
        if report.isLocal {
            return "按日期和标签整理原始记录。AI 分析尚未接入，不推断动机或长期状态。"
        }
        return "原始依据列于下方，可核对原文、补充背景或修正判断。"
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
                color: review.isDemo ? Palette.accent : Palette.steel, filled: true)
    }
}

private struct ReviewPreviewRow: View {
    let number: String
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.accent).padding(.top, 2)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.ink)
                Text(text).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    .lineSpacing(4).lineLimit(2)
            }
        }
    }
}

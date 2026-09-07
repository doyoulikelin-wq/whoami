import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DataTransferView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: TransferRange = .today
    @State private var selectedDate = Date.now
    @State private var format: RecordArchive.Format = .markdown
    @State private var shareItem: RecordShareItem?
    @State private var showingImporter = false
    @State private var statusMessage: String?
    @State private var failure: TransferFailure?

    private var scope: RecordArchive.Scope {
        switch selectedRange {
        case .today: .day(.now)
        case .date: .day(selectedDate)
        case .all: .all
        }
    }

    private var recordCount: Int {
        RecordArchive.filteredEntries(store.entries, scope: scope).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("记录文件").font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text("按日期整理，保留每条记录的具体时间。")
                            .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel("导出范围")
                        Picker("导出范围", selection: $selectedRange) {
                            ForEach(TransferRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("transfer.scope")
                        if selectedRange == .date {
                            DatePicker("选择日期", selection: $selectedDate, displayedComponents: .date)
                                .font(.system(size: 14))
                                .datePickerStyle(.compact)
                                .tint(Palette.ink)
                                .accessibilityIdentifier("transfer.date")
                        }
                        HStack {
                            Text(rangeDescription)
                                .font(.system(size: 11, design: .monospaced))
                            Spacer()
                            Text("\(recordCount) 条记录").font(.system(size: 11))
                                .accessibilityIdentifier("transfer.count")
                        }
                        .foregroundStyle(Palette.secondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        sectionLabel("文件格式")
                        Picker("文件格式", selection: $format) {
                            ForEach(RecordArchive.Format.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("transfer.format")
                        Text(format == .markdown
                             ? "Markdown · 结构清晰，适合阅读或交给 AI 分析。"
                             : "JSON · 完整保留记录字段，可重新导入 WhoAmI。")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(4)
                            .frame(minHeight: 34, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: exportRecords) {
                            Label(recordCount == 0 ? "所选范围暂无记录" : "导出 \(recordCount) 条记录",
                                  systemImage: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(.white)
                                .background(recordCount == 0 ? Palette.secondary : Palette.ink,
                                            in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(recordCount == 0)
                        .accessibilityIdentifier("transfer.export")
                        Text("通过系统分享保存到“文件”，或发送至微信等 App。仅导出已保存的记录。")
                            .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4)
                    }

                    Rectangle().fill(Palette.line).frame(height: 0.5)

                    VStack(alignment: .leading, spacing: 11) {
                        Button { showingImporter = true } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "square.and.arrow.down")
                                Text("导入 JSON 记录").fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 11))
                            }
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.ink)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("transfer.import")
                        Text("选择 WhoAmI 导出的 JSON 文件。按记录 ID 合并，重复记录会跳过，已有内容与草稿保留。")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(4)
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
                                .padding(.top, 3)
                                .accessibilityIdentifier("transfer.status")
                        }
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text("设置").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityIdentifier("transfer.settings")
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
            }
            .pageBackground()
            .navigationTitle("导入与导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.tint(Palette.ink)
                        .accessibilityIdentifier("transfer.done")
                }
            }
            .accessibilityIdentifier("transfer-view")
        }
        .presentationDragIndicator(.visible)
        .sheet(item: $shareItem) { item in
            RecordActivityView(fileURL: item.url) { error in
                if let error {
                    failure = TransferFailure(title: "分享失败", message: error.localizedDescription)
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            importRecords(result)
        }
        .alert(item: $failure) { failure in
            Alert(title: Text(failure.title), message: Text(failure.message), dismissButton: .default(Text("完成")))
        }
    }

    private var rangeDescription: String {
        switch selectedRange {
        case .today: DateText.format(.now, "yyyy.MM.dd")
        case .date: DateText.format(selectedDate, "yyyy.MM.dd")
        case .all: "全部已保存记录"
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.ink)
    }

    private func exportRecords() {
        do {
            let url = try RecordArchive.export(entries: store.entries, scope: scope, format: format)
            shareItem = RecordShareItem(url: url)
        } catch {
            failure = TransferFailure(title: "导出失败", message: error.localizedDescription)
        }
    }

    private func importRecords(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let entries = try RecordArchive.importEntries(from: url)
            let imported = try store.importRecords(entries)
            statusMessage = "已导入 \(imported.added) 条，跳过 \(imported.skipped) 条重复记录。"
            UIAccessibility.post(notification: .announcement, argument: statusMessage)
        } catch {
            let nsError = error as NSError
            guard !(nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError) else { return }
            failure = TransferFailure(title: "导入失败", message: error.localizedDescription)
        }
    }
}

private enum TransferRange: String, CaseIterable, Identifiable {
    case today = "今天"
    case date = "指定日期"
    case all = "全部"
    var id: String { rawValue }
}

private struct RecordShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct TransferFailure: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct RecordActivityView: UIViewControllerRepresentable {
    let fileURL: URL
    let onFailure: (Error?) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, error in
            if let error {
                DispatchQueue.main.async { onFailure(error) }
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

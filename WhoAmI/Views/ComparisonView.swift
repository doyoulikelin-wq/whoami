import SwiftUI

struct ComparisonView: View {
    @EnvironmentObject private var store: AppStore

    private var ownEntries: [JournalEntry] { store.sortedEntries.filter { !$0.isDemo } }
    private var days: [Date] {
        Array(Set(ownEntries.map { Calendar.current.startOfDay(for: $0.createdAt) })).sorted(by: >)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 27) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("COMPARE").font(.system(size: 10, weight: .semibold)).tracking(3)
                        .foregroundStyle(Palette.secondary)
                    Text("对比").font(.system(size: 30, weight: .semibold)).foregroundStyle(Palette.ink)
                }
                if days.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("还没有记录").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                        Text("保存后的记录会按日期排列在这里。")
                            .font(.system(size: 13)).foregroundStyle(Palette.secondary)
                    }.padding(.top, 28)
                } else {
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(DateText.day(day)).font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Text(DateText.format(day, "yyyy.MM.dd"))
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.secondary)
                            }.padding(.bottom, 13)
                            Rectangle().fill(Palette.line).frame(height: 0.5)
                            ForEach(entries(on: day)) { entry in
                                NavigationLink {
                                    ComparisonDetailView(entryID: entry.id)
                                } label: {
                                    comparisonRow(entry)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(rowAccessibilityLabel(entry))
                                .accessibilityIdentifier("comparison.entry.\(entry.id.uuidString)")
                                Rectangle().fill(Palette.line).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 28)
        }
        .pageBackground()
        .accessibilityIdentifier("comparison-view")
    }

    private func entries(on day: Date) -> [JournalEntry] {
        ownEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: day) }
    }

    private func comparisonRow(_ entry: JournalEntry) -> some View {
        HStack(spacing: 15) {
            ComparisonDomainGlyph(domain: entry.domain).frame(width: 31, height: 31)
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.domain?.title ?? "未分类")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ink)
                Text(DateText.format(entry.createdAt, "HH:mm:ss"))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
                    .accessibilityIdentifier("comparison.time.\(entry.id.uuidString)")
            }
            Spacer(minLength: 8)
            if let level = comparisonLevel(entry) {
                MoodFlame(level: level, size: 28, animated: false)
            }
            Text(comparisonLevel(entry).map(String.init) ?? "—")
                .font(.system(size: 19, weight: .light, design: .monospaced))
                .foregroundStyle(Palette.ink).frame(width: 30, alignment: .trailing)
                .accessibilityIdentifier("comparison.level.\(entry.id.uuidString)")
        }
        .padding(.vertical, 20).contentShape(Rectangle())
    }

    private func rowAccessibilityLabel(_ entry: JournalEntry) -> String {
        let domain = entry.domain?.title ?? "未分类"
        let recordedAt = DateText.format(entry.createdAt, "yyyy.MM.dd HH:mm:ss")
        guard let level = comparisonLevel(entry) else { return "\(domain)，心境未记录，记录于 \(recordedAt)" }
        return "\(domain)，心境\(comparisonMoodName(level))，\(level)，记录于 \(recordedAt)"
    }
}

struct ComparisonDetailView: View {
    @EnvironmentObject private var store: AppStore
    let entryID: UUID

    private var entry: JournalEntry? { store.entries.first { $0.id == entryID && !$0.isDemo } }

    var body: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 27) {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack(spacing: 16) {
                            ComparisonDomainGlyph(domain: entry.domain).frame(width: 42, height: 42)
                            Text(entry.domain?.title ?? "未分类")
                                .font(.system(size: 29, weight: .semibold)).foregroundStyle(Palette.ink)
                        }
                        HStack(spacing: 10) {
                            Text("\(DateText.day(entry.createdAt)) · \(DateText.format(entry.createdAt, "yyyy.MM.dd HH:mm:ss"))")
                                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        }
                    }
                    Rectangle().fill(Palette.line).frame(height: 0.5)
                    Text(entry.body)
                        .font(.system(size: 17)).foregroundStyle(Palette.ink).lineSpacing(10)
                        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("comparison.content")
                    Rectangle().fill(Palette.line).frame(height: 0.5)
                    HStack(alignment: .center, spacing: 13) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("当时的心境").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                            Text(comparisonLevel(entry).map(comparisonMoodName) ?? "未记录")
                                .font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink)
                        }
                        Spacer()
                        if let level = comparisonLevel(entry) {
                            MoodFlame(level: level, size: 50, animated: false)
                        }
                        Text(comparisonLevel(entry).map(String.init) ?? "—")
                            .font(.system(size: 34, weight: .light, design: .monospaced))
                            .foregroundStyle(Palette.ink)
                            .accessibilityIdentifier("comparison.detail.level")
                    }
                    if let updatedAt = entry.updatedAt, updatedAt.timeIntervalSince(entry.createdAt) > 60 {
                        Text("修订于 \(DateText.format(updatedAt, "yyyy.MM.dd HH:mm:ss"))")
                            .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 32)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("这条记录已删除").font(.headline).foregroundStyle(Palette.ink)
                    Text("返回对比列表查看其他记录。")
                        .font(.subheadline).foregroundStyle(Palette.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
        }
        .pageBackground()
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("comparison-detail")
    }
}

private func comparisonLevel(_ entry: JournalEntry) -> Int? {
    guard let level = entry.moodIntensity, (1...99).contains(level) else { return nil }
    return level
}

private func comparisonMoodName(_ level: Int) -> String {
    switch level {
    case 1...33: "淡漠"
    case 34...66: "平静"
    default: "冲动"
    }
}

private struct ComparisonDomainGlyph: View {
    let domain: LifeDomain?
    var body: some View {
        if let domain {
            DimensionGlyph(domain: domain)
        } else {
            RoundedRectangle(cornerRadius: 2).stroke(Palette.ink, lineWidth: 1.5)
                .padding(5)
                .overlay { Rectangle().fill(Palette.ink).frame(width: 10, height: 1.5) }
                .accessibilityHidden(true)
        }
    }
}

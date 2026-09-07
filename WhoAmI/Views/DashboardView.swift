import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingTransfer = false

    private var ownEntries: [JournalEntry] { store.sortedEntries.filter { !$0.isDemo } }
    private var todayEntries: [JournalEntry] {
        ownEntries.filter { Calendar.current.isDateInToday($0.createdAt) }
    }
    private var todayDomainCount: Int { Set(todayEntries.compactMap(\.domain)).count }
    private var activity: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (-6...0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (day, ownEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("WHOAMI").font(.system(size: 10, weight: .semibold)).tracking(3)
                            .foregroundStyle(Palette.secondary)
                        Text("总览").font(.system(size: 30, weight: .semibold)).foregroundStyle(Palette.ink)
                    }
                    Spacer()
                    Text(DateText.format(.now, "yyyy.MM.dd"))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.secondary)
                        .padding(.bottom, 5)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(todayDomainCount)").font(.system(size: 34, weight: .light, design: .monospaced))
                        .foregroundStyle(Palette.ink)
                    Text("/ 7").font(.system(size: 18, weight: .light, design: .monospaced))
                        .foregroundStyle(Palette.secondary)
                    Text("今日已记录维度").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    Spacer(minLength: 4)
                    Text("\(todayEntries.count) 条记录").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("今天已记录 \(todayDomainCount) 个维度，共 7 个维度，\(todayEntries.count) 条真实记录")
                .accessibilityIdentifier("dashboard.coverage")

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("七个维度").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("最新记录").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    }.padding(.bottom, 10)
                    Rectangle().fill(Palette.line).frame(height: 0.5)
                    ForEach(LifeDomain.allCases) { domain in
                        dimensionRow(domain)
                        Rectangle().fill(Palette.line).frame(height: 0.5)
                    }
                }

                activityChart

                Button("导入与导出") { showingTransfer = true }
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("dashboard.transfer")
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
        }
        .pageBackground()
        .accessibilityIdentifier("dashboard-view")
        .sheet(isPresented: $showingTransfer) {
            DataTransferView()
        }
    }

    private func dimensionRow(_ domain: LifeDomain) -> some View {
        let entry = ownEntries.first { $0.domain == domain }
        let level = entry?.moodIntensity.flatMap { (1...99).contains($0) ? $0 : nil }
        return HStack(spacing: 13) {
            DimensionGlyph(domain: domain).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(domain.title).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    if let entry {
                        Text(DateText.format(entry.createdAt,
                            Calendar.current.component(.year, from: entry.createdAt) == Calendar.current.component(.year, from: .now)
                                ? "MM.dd HH:mm" : "yyyy.MM.dd HH:mm"))
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.secondary)
                            .accessibilityLabel("记录于 \(DateText.format(entry.createdAt, "yyyy.MM.dd HH:mm:ss"))")
                            .accessibilityIdentifier("dashboard.time.\(domain.rawValue)")
                    }
                }
                Text(entry.map { $0.body.replacingOccurrences(of: "\n", with: " ") } ?? "尚无记录")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let level {
                MoodFlame(level: level, size: 23, animated: false)
                Text(level <= 33 ? "淡漠" : level <= 66 ? "平静" : "冲动")
                    .font(.system(size: 10)).foregroundStyle(Palette.ink)
                    .frame(width: 25, alignment: .trailing)
            } else {
                Text("未记录").font(.system(size: 9)).foregroundStyle(Palette.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dashboard.domain.\(domain.rawValue)")
    }

    private var activityChart: some View {
        let days = activity
        let maximum = max(days.map(\.count).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("近 7 天").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(days.reduce(0) { $0 + $1.count }) 条真实记录")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            HStack(alignment: .bottom, spacing: 15) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 5) {
                        Text("\(day.count)").font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Palette.secondary)
                        VStack {
                            Spacer(minLength: 0)
                            Rectangle().fill(day.count == 0 ? Palette.line : Palette.ink)
                                .frame(height: day.count == 0 ? 1 : 30 * CGFloat(day.count) / CGFloat(maximum))
                        }.frame(height: 30)
                        Text(Calendar.current.isDateInToday(day.date) ? "今天" : DateText.format(day.date, "M/d"))
                            .font(.system(size: 9)).foregroundStyle(Palette.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(DateText.day(day.date))，\(day.count) 条真实记录")
                }
            }
        }
        .accessibilityIdentifier("dashboard.activity")
    }
}

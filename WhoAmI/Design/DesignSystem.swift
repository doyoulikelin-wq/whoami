import SwiftUI

enum Palette {
    static let background = Color(hex: 0xFAF9F6)
    static let paper = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x282D29)
    static let secondary = Color(hex: 0x73776E)
    static let coral = Color(hex: 0xC85535)
    static let sage = Color(hex: 0x637E6C)
    static let cream = Color(hex: 0xF3EFE6)
    static let line = Color(hex: 0xE7E5DD)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

enum DateText {
    static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
    static func day(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return format(date, "M月d日")
    }
    static func range(_ start: Date, _ end: Date) -> String {
        "\(format(start, "M月d日")) — \(format(end, "M月d日"))"
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow).font(.system(size: 11, weight: .semibold)).tracking(3).foregroundStyle(Palette.sage)
            Text(title).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
            if !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(4)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionHeading: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 19, weight: .semibold)).foregroundStyle(Palette.ink)
            Spacer()
            if let trailing {
                Button(action: { action?() }) {
                    HStack(spacing: 4) { Text(trailing); Image(systemName: "chevron.right").font(.caption2) }
                        .font(.subheadline).foregroundStyle(Palette.sage).frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "plus"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity).frame(minHeight: 54)
                .foregroundStyle(.white)
                .background(Palette.coral, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

struct TagPill: View {
    let text: String
    var icon: String? = nil
    var color = Palette.sage
    var filled = false
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }.font(.system(size: 12, weight: .medium))
            .foregroundStyle(color).padding(.horizontal, 11).padding(.vertical, 7)
            .background(filled ? color.opacity(0.1) : Palette.background,
                        in: Capsule())
            .overlay(Capsule().stroke(color.opacity(filled ? 0 : 0.19), lineWidth: 1))
    }
}

struct DomainIcon: View {
    var domain: LifeDomain?
    var size: CGFloat = 42
    var body: some View {
        Image(systemName: domain?.icon ?? "text.alignleft")
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(domain?.color ?? Palette.sage)
            .frame(width: size, height: size)
            .background((domain?.color ?? Palette.sage).opacity(0.11), in: RoundedRectangle(cornerRadius: size * 0.31))
    }
}

struct EntryRow: View {
    let entry: JournalEntry
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            DomainIcon(domain: entry.domain)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(entry.domain?.title ?? "生活片段").foregroundStyle(entry.domain?.color ?? Palette.sage)
                    if entry.isDemo { Text("示例").foregroundStyle(Palette.secondary) }
                    Spacer(minLength: 4)
                    Text(Calendar.current.isDateInToday(entry.createdAt) ? DateText.format(entry.createdAt, "HH:mm") : DateText.day(entry.createdAt))
                        .foregroundStyle(Palette.secondary)
                }.font(.system(size: 11))
                Text(entry.title).font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(2)
                Text(entry.body.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 13)).foregroundStyle(Palette.secondary).lineLimit(2).lineSpacing(4)
            }
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.secondary).padding(.top, 31)
        }.padding(.vertical, 17).contentShape(Rectangle())
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundStyle(Palette.sage).padding(.bottom, 5)
            Text(title).font(.headline).foregroundStyle(Palette.ink)
            Text(detail).font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center).lineSpacing(5)
        }.frame(maxWidth: .infinity).padding(.vertical, 38).padding(.horizontal, 22)
    }
}

extension View {
    func pageBackground() -> some View {
        self.background(Palette.background.ignoresSafeArea()).toolbarBackground(Palette.background, for: .navigationBar)
    }
    func paperPanel() -> some View {
        self.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22))
    }
}

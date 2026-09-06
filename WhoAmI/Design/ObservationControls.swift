import SwiftUI

/// Seven domains share one circle. The selected sector settles at the top.
struct DimensionWheel: View {
    @Binding var selection: LifeDomain
    var savedLevels: [LifeDomain: Int]
    var diameter: CGFloat = 286

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation = 0.0
    @State private var dragStartIndex: Int?
    @State private var dragIntent: DragIntent?
    @State private var previousAngle: Double?
    @State private var accumulatedAngle = 0.0

    private let domains = LifeDomain.allCases
    private enum DragIntent { case horizontal, vertical, arc }
    private var step: Double { 2 * .pi / Double(domains.count) }
    private var selectedIndex: Int { domains.firstIndex(of: selection) ?? 0 }
    private var side: CGFloat { max(180, diameter) }
    private var radius: CGFloat { side / 2 - 15 }

    var body: some View {
        ZStack {
            ForEach(Array(domains.enumerated()), id: \.element.id) { index, domain in
                sector(index: index, domain: domain)
            }
            Circle().stroke(Palette.ink.opacity(0.65), lineWidth: 1)
                .frame(width: radius * 2, height: radius * 2)
                .allowsHitTesting(false)
        }
        .rotationEffect(.radians(rotation))
        .frame(width: side, height: side)
        .contentShape(Circle())
        .simultaneousGesture(rotationGesture)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("观察维度，当前为\(selection.title)")
        .accessibilityHint("左右轻扫切换维度，也可直接选择图标。")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: select(offset: 1, from: selectedIndex)
            case .decrement: select(offset: -1, from: selectedIndex)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("dimension-wheel")
        .onAppear { settleRotation(animated: false) }
        .onChange(of: selection) { _, _ in settleRotation(animated: true) }
    }

    private func sector(index: Int, domain: LifeDomain) -> some View {
        let angle = -.pi / 2 + Double(index) * step
        let wedge = WheelSector(start: angle - step / 2, end: angle + step / 2, inset: 15)
        return ZStack {
            ZStack {
                wedge.fill(selection == domain ? Palette.line : Palette.paper)
                wedge.stroke(selection == domain ? Palette.ink : Palette.line,
                             lineWidth: selection == domain ? 1.6 : 0.8)
            }
            .contentShape(wedge)
            .onTapGesture { selection = domain }
            .accessibilityHidden(true)

            Button { selection = domain } label: {
                DimensionGlyph(domain: domain)
                    .frame(width: side * 0.105, height: side * 0.105)
                    .frame(width: min(48, side * 0.18), height: min(48, side * 0.18))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(domain.title + (savedLevels[domain] == nil ? "，未记录" : "，已记录"))
            .accessibilityAddTraits(selection == domain ? [.isSelected] : [])
            .accessibilityIdentifier("wheel.domain.\(domain.rawValue)")
            .rotationEffect(.radians(-rotation))
            .position(point(at: angle, radius: radius * 0.59))

            if let level = savedLevels[domain] {
                MoodFlame(level: level, size: side * 0.079)
                    .rotationEffect(.radians(-rotation))
                    .position(point(at: angle, radius: radius * 0.95))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: side, height: side)
    }

    private func point(at angle: Double, radius: CGFloat) -> CGPoint {
        CGPoint(x: side / 2 + CGFloat(cos(angle)) * radius,
                y: side / 2 + CGFloat(sin(angle)) * radius)
    }

    private var rotationGesture: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { drag in
                if dragStartIndex == nil {
                    dragStartIndex = selectedIndex
                    dragIntent = initialIntent(for: drag)
                    previousAngle = atan2(Double(drag.startLocation.y - side / 2),
                                          Double(drag.startLocation.x - side / 2))
                    accumulatedAngle = 0
                }
                guard dragIntent != .vertical else { return }
                let angle = atan2(Double(drag.location.y - side / 2), Double(drag.location.x - side / 2))
                if let previousAngle { accumulatedAngle += normalized(angle - previousAngle) }
                previousAngle = angle
                guard let start = dragStartIndex else { return }
                let dx = drag.translation.width
                // Intent is locked at the beginning, so a vertical scroll cannot
                // become a domain change when the finger drifts sideways later.
                if dragIntent == .horizontal {
                    let offset = Int((-dx / max(30, side * 0.16)).rounded())
                    select(offset: offset, from: start)
                } else if dragIntent == .arc, abs(accumulatedAngle) > step * 0.45 {
                    let offset = -Int((accumulatedAngle / step).rounded())
                    select(offset: offset, from: start)
                }
            }
            .onEnded { _ in
                dragStartIndex = nil
                dragIntent = nil
                previousAngle = nil
                accumulatedAngle = 0
            }
    }

    private func initialIntent(for drag: DragGesture.Value) -> DragIntent {
        let dx = abs(drag.translation.width)
        let dy = abs(drag.translation.height)
        if dy > dx * 1.2 { return .vertical }
        if dx > dy * 1.2 { return .horizontal }

        let startX = drag.startLocation.x - side / 2
        let startY = drag.startLocation.y - side / 2
        let endX = drag.location.x - side / 2
        let endY = drag.location.y - side / 2
        let startRadius = hypot(startX, startY)
        let endRadius = hypot(endX, endY)
        // A diagonal start counts as a turn only on the ring and approximately
        // tangent to it. Ambiguous or radial movement remains a scroll.
        if startRadius > radius * 0.45,
           abs(endRadius - startRadius) < hypot(dx, dy) * 0.35 {
            return .arc
        }
        return .vertical
    }

    private func select(offset: Int, from index: Int) {
        let next = (index + offset % domains.count + domains.count) % domains.count
        if selection != domains[next] { selection = domains[next] }
    }

    private func normalized(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }

    private func settleRotation(animated: Bool) {
        let next = rotation + normalized(-Double(selectedIndex) * step - rotation)
        if animated && !reduceMotion {
            withAnimation(.easeOut(duration: 0.24)) { rotation = next }
        } else {
            rotation = next
        }
    }
}

private struct WheelSector: Shape {
    var start: Double
    var end: Double
    var inset: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(0, min(rect.width, rect.height) / 2 - inset)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: .radians(start),
                    endAngle: .radians(end), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// Original line art, drawn in normalized coordinates rather than symbol fonts.
struct DimensionGlyph: View {
    var domain: LifeDomain

    var body: some View {
        GlyphSizingLayout {
            Canvas { context, size in
                let edge = min(size.width, size.height)
                let origin = CGPoint(x: (size.width - edge) / 2, y: (size.height - edge) / 2)
                let transform = CGAffineTransform(scaleX: edge, y: edge)
                    .concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
                context.stroke(glyphPath.applying(transform), with: .color(Palette.ink),
                               style: StrokeStyle(lineWidth: max(1, edge * 0.055), lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }

    private var glyphPath: Path {
        var p = Path()
        func move(_ x: CGFloat, _ y: CGFloat) { p.move(to: CGPoint(x: x, y: y)) }
        func line(_ x: CGFloat, _ y: CGFloat) { p.addLine(to: CGPoint(x: x, y: y)) }
        switch domain {
        case .career:
            move(0.13, 0.88); line(0.87, 0.88)
            move(0.28, 0.88); line(0.28, 0.31); line(0.72, 0.31); line(0.72, 0.88)
            move(0.39, 0.31); line(0.39, 0.19); line(0.61, 0.19); line(0.61, 0.31)
            move(0.50, 0.08); line(0.50, 0.19)
            for y in [0.46, 0.62, 0.77] {
                move(0.39, y); line(0.45, y); move(0.56, y); line(0.62, y)
            }
        case .finance:
            move(0.12, 0.31); line(0.50, 0.13); line(0.88, 0.31); line(0.50, 0.49); p.closeSubpath()
            move(0.12, 0.49); line(0.50, 0.67); line(0.88, 0.49)
            move(0.12, 0.68); line(0.50, 0.86); line(0.88, 0.68)
            move(0.12, 0.31); line(0.12, 0.42)
            move(0.88, 0.31); line(0.88, 0.42)
        case .body:
            p.addEllipse(in: CGRect(x: 0.405, y: 0.08, width: 0.19, height: 0.19))
            move(0.33, 0.35)
            p.addQuadCurve(to: CGPoint(x: 0.17, y: 0.48), control: CGPoint(x: 0.22, y: 0.36))
            line(0.28, 0.61); line(0.33, 0.89); line(0.67, 0.89); line(0.72, 0.61); line(0.83, 0.48)
            p.addQuadCurve(to: CGPoint(x: 0.67, y: 0.35), control: CGPoint(x: 0.78, y: 0.36))
            move(0.50, 0.36); line(0.50, 0.79)
            move(0.34, 0.56); line(0.66, 0.56)
        case .emotion:
            for y in [0.27, 0.50, 0.73] {
                move(0.10, y)
                p.addCurve(to: CGPoint(x: 0.50, y: y), control1: CGPoint(x: 0.23, y: y - 0.18),
                           control2: CGPoint(x: 0.35, y: y + 0.18))
                p.addCurve(to: CGPoint(x: 0.90, y: y), control1: CGPoint(x: 0.65, y: y - 0.18),
                           control2: CGPoint(x: 0.77, y: y + 0.18))
            }
        case .learning:
            move(0.23, 0.11); line(0.60, 0.11); line(0.82, 0.33); line(0.82, 0.89); line(0.23, 0.89); p.closeSubpath()
            move(0.60, 0.11); line(0.60, 0.33); line(0.82, 0.33)
            move(0.36, 0.51); line(0.68, 0.51)
            move(0.36, 0.66); line(0.61, 0.66)
            move(0.36, 0.78); line(0.53, 0.78)
        case .relationships:
            p.addEllipse(in: CGRect(x: 0.08, y: 0.25, width: 0.51, height: 0.51))
            p.addEllipse(in: CGRect(x: 0.41, y: 0.25, width: 0.51, height: 0.51))
        case .life:
            move(0.82, 0.13); line(0.64, 0.83); line(0.45, 0.55); line(0.16, 0.37); p.closeSubpath()
            move(0.45, 0.55); line(0.82, 0.13)
            move(0.14, 0.86); line(0.28, 0.72)
        }
        return p
    }
}

private struct GlyphSizingLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 32
        let height = proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? 32
        return CGSize(width: width, height: height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
        }
    }
}

/// Level changes the drawing within a stable square, not the surrounding layout.
struct MoodFlame: View {
    var level: Int
    var size: CGFloat = 42
    var animated: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedLevel: Int { min(max(level, 1), 99) }

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                    drawing(phase: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                drawing(phase: 0)
            }
        }
        .frame(width: max(1, size), height: max(1, size))
        .accessibilityHidden(true)
    }

    private func drawing(phase: Double) -> some View {
        Canvas { context, bounds in
            let intensity = Double(clampedLevel) / 99
            let tier = (clampedLevel - 1) / 33
            let motion = animated && !reduceMotion ? sin(phase * (2.2 + intensity * 6.8)) : 0
            let sway = motion * (0.008 + intensity * 0.05)
            let widthScale = 0.60 + intensity * 0.30
            let heightScale = 0.64 + intensity * 0.30
            var path = Path()
            func point(_ x: Double, _ y: Double) -> CGPoint {
                let horizontal = 0.5 + (x - 0.5) * widthScale + sway * (1 - y)
                let vertical = 0.94 - (0.94 - y) * heightScale * (1 + motion * intensity * 0.08)
                return CGPoint(x: horizontal * bounds.width, y: vertical * bounds.height)
            }
            func move(_ x: Double, _ y: Double) { path.move(to: point(x, y)) }
            func curve(_ x: Double, _ y: Double, _ a: Double, _ b: Double, _ c: Double, _ d: Double) {
                path.addCurve(to: point(x, y), control1: point(a, b), control2: point(c, d))
            }
            move(0.50, 0.94)
            if tier == 0 {
                curve(0.27, 0.72, 0.28, 0.94, 0.20, 0.83)
                curve(0.52, 0.10, 0.26, 0.50, 0.53, 0.38)
                curve(0.72, 0.69, 0.76, 0.37, 0.62, 0.48)
                curve(0.50, 0.94, 0.86, 0.87, 0.69, 0.94)
            } else if tier == 1 {
                curve(0.16, 0.70, 0.25, 0.96, 0.11, 0.84)
                curve(0.28, 0.38, 0.10, 0.56, 0.28, 0.54)
                curve(0.37, 0.58, 0.37, 0.42, 0.35, 0.51)
                curve(0.53, 0.04, 0.52, 0.38, 0.38, 0.22)
                curve(0.68, 0.50, 0.73, 0.26, 0.68, 0.37)
                curve(0.81, 0.35, 0.72, 0.47, 0.79, 0.42)
                curve(0.85, 0.73, 0.86, 0.51, 0.98, 0.62)
                curve(0.50, 0.94, 0.85, 0.87, 0.69, 0.95)
            } else {
                curve(0.10, 0.70, 0.26, 0.97, 0.07, 0.88)
                curve(0.16, 0.31, 0.04, 0.53, 0.19, 0.51)
                curve(0.29, 0.53, 0.32, 0.38, 0.26, 0.45)
                curve(0.31, 0.13, 0.45, 0.36, 0.24, 0.26)
                curve(0.48, 0.39, 0.49, 0.21, 0.42, 0.28)
                curve(0.59, 0.02, 0.62, 0.27, 0.48, 0.18)
                curve(0.69, 0.48, 0.82, 0.23, 0.66, 0.34)
                curve(0.85, 0.20, 0.82, 0.44, 0.82, 0.31)
                curve(0.91, 0.73, 0.83, 0.42, 1.02, 0.57)
                curve(0.50, 0.94, 0.91, 0.88, 0.71, 0.96)
            }
            path.closeSubpath()
            context.fill(path, with: .color(Palette.ink))
            var core = Path()
            core.move(to: point(0.47, 0.87))
            core.addCurve(to: point(0.57, 0.55), control1: point(0.38, 0.78), control2: point(0.55, 0.67))
            core.addCurve(to: point(0.58, 0.87), control1: point(0.69, 0.71), control2: point(0.64, 0.81))
            core.closeSubpath()
            context.fill(core, with: .color(Palette.surface))
        }
    }
}

struct MoodEnergyControl: View {
    @Binding var value: Int
    @Binding var isCommitted: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beganCollapsed: Bool?
    @State private var changedDuringDrag = false
    @State private var isTracking = false

    private var band: Int { (min(max(value, 1), 99) - 1) / 33 }
    private let names = ["淡漠", "平静", "冲动"]
    private let levels = [17, 50, 83]

    var body: some View {
        GeometryReader { geometry in
            Group {
                if isCommitted {
                    MoodFlame(level: value, size: 54)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("按住拖动，选择此刻心境")
                            .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        expandedBar(width: geometry.size.width)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { drag in
                    if beganCollapsed == nil {
                        beganCollapsed = isCommitted
                        changedDuringDrag = false
                        changePresentation(committed: false)
                    }
                    if beganCollapsed == false || abs(drag.translation.width) > 6 {
                        setValue(at: drag.location.x, width: geometry.size.width)
                        changedDuringDrag = true
                        isTracking = true
                    }
                }
                .onEnded { _ in
                    if changedDuringDrag { changePresentation(committed: true) }
                    beganCollapsed = nil
                    changedDuringDrag = false
                    isTracking = false
                })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isCommitted ? "心境，\(names[band])" : "选择心境：淡漠、平静或冲动")
            .accessibilityHint(isCommitted ? "点按展开，或上下轻扫调整。" : "上下轻扫选择心境。")
            .accessibilityIdentifier(isCommitted ? "mood-flame-selection" : "mood-energy-bar")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = levels[min(band + 1, 2)]
                case .decrement: value = levels[max(band - 1, 0)]
                @unknown default: return
                }
                changePresentation(committed: true)
            }
            .accessibilityAction {
                changePresentation(committed: !isCommitted)
            }
        }
        .frame(height: isCommitted ? 70 : 100)
    }

    private func expandedBar(width: CGFloat) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                VStack(spacing: 5) {
                    MoodFlame(level: levels[index], size: 34, animated: false)
                    Text(names[index]).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(index == 2 ? Color.white : Palette.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background([Color(hex: 0xDCE1E5), Color(hex: 0xAEB7BF), Color(hex: 0x69747E)][index])
                .overlay(Rectangle().stroke(Palette.ink.opacity(0.26), lineWidth: 0.7))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            if isTracking {
                Rectangle().fill(Palette.ink).frame(width: 2)
                    .padding(.vertical, 6)
                    .offset(x: min(max(0, width * CGFloat(min(max(value, 1), 99) - 1) / 98), max(0, width - 2)))
                    .allowsHitTesting(false)
            }
        }
    }

    private func setValue(at x: CGFloat, width: CGFloat) {
        guard width > 0, width.isFinite else { return }
        let fraction = min(max(x / width, 0), 1)
        value = min(max(Int((fraction * 98).rounded()) + 1, 1), 99)
    }

    private func changePresentation(committed: Bool) {
        if reduceMotion {
            isCommitted = committed
        } else {
            withAnimation(.easeOut(duration: 0.18)) { isCommitted = committed }
        }
    }
}

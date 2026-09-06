import Foundation

struct DimensionDraft: Codable, Equatable {
    var body: String = ""
    var intensity: Int = 50
    var hasChosenIntensity: Bool = false
}

extension LifeDomain {
    var prompt: String {
        switch self {
        case .career: "正在推进什么？实际产生了什么结果？"
        case .finance: "资源发生了什么变化？哪些支出或决定需要记录？"
        case .body: "身体和精力如何？发生了哪些具体变化？"
        case .emotion: "什么触发了你的反应？你如何应对？"
        case .learning: "形成了什么认识？哪些判断仍需要证据？"
        case .relationships: "发生了怎样的互动？你的边界在哪里？"
        case .life: "时间由谁决定？今天的安排符合你的选择吗？"
        }
    }
}

enum MoodBand {
    static func title(for value: Int) -> String {
        switch min(99, max(1, value)) {
        case 1...33: "淡漠"
        case 34...66: "平静"
        default: "冲动"
        }
    }
}

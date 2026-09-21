import Foundation

/// 功能牌：不改变化学，只改变流程
enum ActionCard: String, CaseIterable, Codable, Hashable {
    /// 注液泵：下家摸两张并跳过回合
    case pump
    /// 惰性气氛：本家下家跳过一回合
    case inert
    /// 可逆反应：出牌方向反转
    case reversible
    /// 检液：查看牌堆顶若干张
    case assay

    var displayName: String {
        switch self {
        case .pump: return "注液泵"
        case .inert: return "惰性气氛"
        case .reversible: return "可逆反应"
        case .assay: return "检液"
        }
    }

    /// 牌面中央的符号（SF Symbol）
    var symbol: String {
        switch self {
        case .pump: return "drop.circle.fill"
        case .inert: return "pause.circle.fill"
        case .reversible: return "arrow.triangle.2.circlepath"
        case .assay: return "eye.circle.fill"
        }
    }

    var cornerMark: String {
        switch self {
        case .pump: return "+2"
        case .inert: return "跳过"
        case .reversible: return "反向"
        case .assay: return "检液"
        }
    }

    var instruction: String {
        switch self {
        case .pump: return "下家摸两张牌并跳过本回合"
        case .inert: return "下家跳过一回合"
        case .reversible: return "出牌方向反转"
        case .assay: return "查看牌堆顶 \(previewCount) 张牌"
        }
    }

    var previewCount: Int { self == .assay ? 3 : 0 }
}

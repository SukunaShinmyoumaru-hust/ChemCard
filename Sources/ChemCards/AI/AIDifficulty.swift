import Foundation

/// AI 强度档位
enum AIDifficulty: String, CaseIterable, Codable {
    case novice
    case intermediate
    case expert

    var displayName: String {
        switch self {
        case .novice: return "初级 AI"
        case .intermediate: return "进阶 AI"
        case .expert: return "高级 AI"
        }
    }

    var summary: String {
        switch self {
        case .novice: return "会出的牌随机挑一张，功能牌随手用，偶尔忘了喊「反应!」"
        case .intermediate: return "贪心拿最高分，懂得把万能时机留到最后"
        case .expert: return "一层前瞻：算自己下回合有没有牌接，也算对手能不能压住"
        }
    }

    var shortName: String {
        switch self {
        case .novice: return "初"
        case .intermediate: return "进"
        case .expert: return "高"
        }
    }

    /// 三档各一，作为「混合」桌
    static let mixedTable: [AIDifficulty] = [.novice, .intermediate, .expert]
}

/// 整桌难度预设（开局菜单选这个）
enum TableDifficulty: String, CaseIterable, Identifiable {
    case novice
    case intermediate
    case expert
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .novice: return "初级 AI"
        case .intermediate: return "进阶 AI"
        case .expert: return "高级 AI"
        case .mixed: return "混合桌"
        }
    }

    var summary: String {
        switch self {
        case .novice: return "三个新手，随便乱出，适合认牌"
        case .intermediate: return "个个都拿最高分，会留功能牌"
        case .expert: return "三家都会算下回合，出手很脏"
        case .mixed: return "初级/进阶/高级各一个，节奏最自然"
        }
    }

    /// 三家 AI 的档位
    var seats: [AIDifficulty] {
        switch self {
        case .novice: return [.novice, .novice, .novice]
        case .intermediate: return [.intermediate, .intermediate, .intermediate]
        case .expert: return [.expert, .expert, .expert]
        case .mixed: return AIDifficulty.mixedTable
        }
    }
}

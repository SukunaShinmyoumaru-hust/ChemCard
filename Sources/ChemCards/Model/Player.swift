import Foundation

/// 座位上的角色（东方 Project 风格的原创立绘，图片可替换）
enum CharacterID: String, CaseIterable, Codable, Identifiable {
    case sanae
    case reimu
    case marisa
    case seiga
    case sakuya
    case cirno
    case eirin

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sanae: return "东风谷早苗"
        case .reimu: return "博丽灵梦"
        case .marisa: return "雾雨魔理沙"
        case .seiga: return "鬼人正邪"
        case .sakuya: return "十六夜咲夜"
        case .cirno: return "琪露诺"
        case .eirin: return "八意永琳"
        }
    }

    /// Resources/Characters/<folder>/ 下的立绘目录名
    var folder: String { rawValue }
}

struct Player: Identifiable, Equatable {
    let seat: Int
    let name: String
    let character: CharacterID
    /// nil 表示人类玩家
    let difficulty: AIDifficulty?

    var hand: [Card] = []
    var calledReaction = false
    /// 技能每局只能用一次
    var skillUsed = false
    /// 还欠几回合不能出牌（琪露诺「完美冻结」把自己冻住）
    var frozen = 0

    var id: Int { seat }
    var isHuman: Bool { difficulty == nil }
    var handCount: Int { hand.count }
}

/// 开局阵容
enum MatchSetup {

    /// 一张牌桌的人数：你 + 三家 AI
    static let seatCount = 4

    /// 你坐 0 号位先出牌，其余三角由 AI 扮演。
    /// 从「不是你」的角色里按你在阵容里的下标轮转取人：换主角就换对手，
    /// 且没有随机，测试跑出来的局面可以复现。
    static func seats(human: CharacterID = .sanae, table: TableDifficulty) -> [Player] {
        let levels = table.seats
        let rivals = CharacterID.allCases.filter { $0 != human }
        let offset = CharacterID.allCases.firstIndex(of: human) ?? 0
        var list = [Player(seat: 0, name: "你", character: human, difficulty: nil)]
        for index in levels.indices {
            let character = rivals[(offset + index) % rivals.count]
            list.append(Player(seat: index + 1,
                               name: character.displayName,
                               character: character,
                               difficulty: levels[index]))
        }
        return list
    }

    /// 你 + 三个同档 AI
    static func standard(difficulty: AIDifficulty) -> [Player] {
        seats(human: .sanae, table: TableDifficulty(rawValue: difficulty.rawValue) ?? .expert)
    }

    /// 纯 AI 自动对局（自检、平衡测试用）
    static func allAI(difficulty: AIDifficulty) -> [Player] {
        CharacterID.allCases.prefix(seatCount).enumerated().map { index, character in
            Player(seat: index, name: character.displayName, character: character, difficulty: difficulty)
        }
    }
}

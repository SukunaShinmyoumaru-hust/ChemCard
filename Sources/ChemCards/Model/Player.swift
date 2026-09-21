import Foundation

/// 座位上的角色（东方 Project 风格的原创立绘，图片可替换）
enum CharacterID: String, CaseIterable, Codable, Identifiable {
    case reimu
    case marisa
    case youmu
    case sanae

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reimu: return "博丽灵梦"
        case .marisa: return "雾雨魔理沙"
        case .youmu: return "魂魄妖梦"
        case .sanae: return "东风谷早苗"
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

    var id: Int { seat }
    var isHuman: Bool { difficulty == nil }
    var handCount: Int { hand.count }
}

/// 开局阵容
enum MatchSetup {

    /// 你坐 0 号位先出牌，其余三角由 AI 扮演
    static func seats(human: CharacterID = .reimu, table: TableDifficulty) -> [Player] {
        var list = [Player(seat: 0, name: "你", character: human, difficulty: nil)]
        let rivals = CharacterID.allCases.filter { $0 != human }
        let levels = table.seats
        for (index, character) in rivals.enumerated() {
            list.append(Player(seat: index + 1,
                               name: character.displayName,
                               character: character,
                               difficulty: levels[index]))
        }
        return list
    }

    /// 你 + 三个同档 AI
    static func standard(difficulty: AIDifficulty) -> [Player] {
        seats(human: .reimu, table: TableDifficulty(rawValue: difficulty.rawValue) ?? .expert)
    }

    /// 纯 AI 自动对局（自检、平衡测试用）
    static func allAI(difficulty: AIDifficulty) -> [Player] {
        CharacterID.allCases.enumerated().map { index, character in
            Player(seat: index, name: character.displayName, character: character, difficulty: difficulty)
        }
    }
}

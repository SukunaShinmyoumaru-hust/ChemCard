import Foundation

/// 卡牌类别（相当于 UNO 的颜色/花色）
enum CardCategory: String, Codable, CaseIterable, Hashable {
    case acid = "酸"
    case base = "碱"
    case salt = "盐"
    case metal = "金属"
    case nonmetal = "非金属"
    case metalOxide = "金属氧化物"
    case nonmetalOxide = "非金属氧化物"
    case organic = "有机物"
    case function = "功能"

    var displayName: String { rawValue }

    /// 同类别内的「族」，用于连锁倍率判定
    var family: CardFamily {
        switch self {
        case .acid, .base: return .compound
        case .salt: return .compound
        case .metal, .nonmetal: return .element
        case .metalOxide, .nonmetalOxide: return .oxide
        case .organic: return .organic
        case .function: return .special
        }
    }
}

enum CardFamily: String, Codable {
    case compound, element, oxide, organic, special
}

/// 知识难度分层：高中反应给更高分
enum KnowledgeTier: Int, Codable, CaseIterable, Comparable {
    case junior = 0     // 初中
    case senior = 1     // 高中

    var displayName: String { self == .junior ? "初中" : "高中" }
    var bonusPoints: Int { self == .junior ? 0 : 8 }

    static func < (lhs: KnowledgeTier, rhs: KnowledgeTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum Solubility: String, Codable, CaseIterable {
    case soluble = "可溶"
    case slight = "微溶"
    case insoluble = "难溶"

    var isUsableInSolution: Bool { self != .insoluble }
}

/// 颜色提示（沉淀颜色 / 溶液颜色）
enum ColorHint: String, Codable {
    case white = "白色"
    case blue = "蓝色"
    case paleGreen = "浅绿色"
    case green = "绿色"
    case redBrown = "红褐色"
    case yellow = "黄色"
    case black = "黑色"
    case purple = "紫红色"
    case silverWhite = "银白色"
    case red = "红色"
    case paleYellow = "淡黄色"
}

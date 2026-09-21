import Foundation

enum CardKind: Hashable {
    case species(Species)
    case action(ActionCard)
}

/// 一张实体牌。`uid` 只在一局牌内唯一，用于 SwiftUI 身份标识与出牌定位。
struct Card: Identifiable, Hashable {
    let uid: Int
    let kind: CardKind

    var id: Int { uid }

    var species: Species? {
        if case .species(let value) = kind { return value }
        return nil
    }

    var action: ActionCard? {
        if case .action(let value) = kind { return value }
        return nil
    }

    var category: CardCategory { species?.category ?? .function }

    /// 牌面主标题：中文名
    var title: String { species?.name ?? action?.displayName ?? "" }

    /// 牌面化学式（含 Unicode 下标），有机物等没有式样的用英文名
    var formulaLine: String {
        if let species { return species.displayFormula }
        return action?.cornerMark ?? ""
    }

    var note: String? { species?.note }

    /// 反应活性刻度 0–9，牌面右上角数字：金属按活动性顺序，其余按化学式散列，同一物种永远同值
    var activityScale: Int {
        guard let species else { return 0 }
        if species.isMetal, let rank = species.activityRank {
            return max(0, min(9, 9 - rank))
        }
        let hash = Int(species.formula.unicodeScalars.reduce(0) { $0 + Int($1.value) })
        return (hash + (species.tier == .senior ? 3 : 0)) % 10
    }
}

extension Card {
    init(species: Species, uid: Int) {
        self.init(uid: uid, kind: .species(species))
    }

    init(action: ActionCard, uid: Int) {
        self.init(uid: uid, kind: .action(action))
    }
}

/// 出牌裁定结果
enum Playability: Equatable {
    /// 与容器中的物质能反应
    case reacts(Reaction)
    /// 功能牌，永远可出
    case action(ActionCard)
    /// 不能出，附带教学原因
    case illegal(reason: String)

    var isPlayable: Bool { !isIllegal }

    var isIllegal: Bool {
        if case .illegal = self { return true }
        return false
    }
}

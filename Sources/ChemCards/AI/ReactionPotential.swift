import Foundation

/// 容器对「未知的手」有多大吸引力：池子里能和其中任意一种物质反应的物种占比，
/// 扣掉已经暴露在弃牌堆里的份数。只使用公开信息，所以高级 AI 拿它评估
/// 「我倒进去这个会不会被下家压住」。
enum ReactionPotential {

    static func partners(of contents: [Species]) -> [Species] {
        let present = Set(contents.map(\.id))
        return Chemistry.all.filter { species in
            !present.contains(species.id) && contents.contains { ReactionEngine.resolve($0, species) != nil }
        }
    }

    /// 0 = 几乎没人接得住，1 = 池子里将近一半的牌都能压住它
    static func openness(of contents: [Species], discard: [Card]) -> Double {
        let partners = partners(of: contents)
        guard !partners.isEmpty else { return 0 }
        let partnerIDs = Set(partners.map(\.id))
        let spent = Set(discard.compactMap { $0.species?.id }).intersection(partnerIDs).count
        let remaining = Double(max(0, partners.count - spent))
        return max(0, min(1, remaining / Double(Chemistry.all.count)))
    }

    /// 自己手里能接住这个混合物的牌数
    static func answers(in hand: [Card], for contents: [Species]) -> Int {
        hand.filter { card in
            guard let species = card.species else { return card.action != nil }
            return ReactionEngine.resolve(anyOf: contents, with: species) != nil
        }.count
    }
}

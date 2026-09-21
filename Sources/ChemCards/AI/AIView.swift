import Foundation

/// AI 能看到的全部信息。类型上不存在「对手手牌」，只有数量与公开的弃牌堆，
/// LegalityTests/AITests 用反射断言这一点，防止以后有人偷偷塞私有牌面进来。
struct AIView {
    let seat: Int
    let hand: [Card]
    /// 容器里现存的物质，最早到最新；任意一种接得上就算出得去
    let contents: [Species]
    /// 出牌后容器里还会留下几种物质
    let window: Int
    let discard: [Card]
    let handCounts: [Int]
    let stockCount: Int
    let pendingDraw: Int
    let isMyTurn: Bool
    let canDraw: Bool
    let legalMoves: [Card]

    var myHandCount: Int { hand.count }

    /// 最新倒进去的那一种，只是给台词和横幅用的指代，判定一律看整个混合物
    var topSpecies: Species? { contents.last }

    var opponentHandCounts: [Int] {
        handCounts.enumerated().filter { $0.offset != seat }.map(\.element)
    }

    /// 一张都打不出、牌堆也空了，这一手只能过
    var mustPass: Bool { legalMoves.isEmpty && !canDraw }

    /// 这张牌打出去会生成什么反应（表里没有就是 nil）
    func reaction(for card: Card) -> Reaction? {
        guard let species = card.species else { return nil }
        return ReactionEngine.resolve(anyOf: contents, with: species)
    }

    /// 打出这张牌之后，容器里会剩下哪几种物质
    func mixture(afterPlay card: Card) -> [Species] {
        guard let species = card.species else { return contents }
        return Array((contents + [species]).suffix(window))
    }
}

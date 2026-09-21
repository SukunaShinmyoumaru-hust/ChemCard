import Foundation

/// 三档 AI 的决策。全部只读 `AIView`，类型上拿不到对手手牌。
enum AIPlanner {

    static func decide(for view: AIView, as difficulty: AIDifficulty, rng: inout SplitMix64) -> GameState.Decision {
        switch difficulty {
        case .novice: return novice(view, rng: &rng)
        case .intermediate: return greedy(view)
        case .expert: return expert(view)
        }
    }

    // MARK: 初级 —— 会出就随机挑一张，12% 概率保守摸牌，功能牌乱用

    private static func novice(_ view: AIView, rng: inout SplitMix64) -> GameState.Decision {
        let passes = view.canDraw && rng.nextUnit() < 0.12
        guard !passes, let first = view.legalMoves.first else { return fallback(view) }
        if view.legalMoves.count == 1 { return .play(uid: first.uid) }
        let pick = view.legalMoves[rng.nextInt(below: view.legalMoves.count)]
        return .play(uid: pick.uid)
    }

    // MARK: 进阶 —— 贪心拿最高即时价值，把功能牌留到真接不上时

    private static func greedy(_ view: AIView) -> GameState.Decision {
        guard let best = view.legalMoves.max(by: { immediateValue($0, view) < immediateValue($1, view) }) else {
            return fallback(view)
        }
        return .play(uid: best.uid)
    }

    // MARK: 高级 —— 一层前瞻：即时价值 + 自己接得住 + 别人接不住 + 能否一击出完

    private static func expert(_ view: AIView) -> GameState.Decision {
        guard let best = view.legalMoves.max(by: { value($0, view) < value($1, view) }) else {
            return fallback(view)
        }
        return .play(uid: best.uid)
    }

    /// 接不上时：牌堆还有牌就摸一张，都空了只能过这一手
    private static func fallback(_ view: AIView) -> GameState.Decision {
        view.canDraw ? .draw : .pass
    }

    /// reaction.points 是反应表给这一次反应定的权重，只用来给 AI 比较牌面
    private static func immediateValue(_ card: Card, _ view: AIView) -> Int {
        if let reaction = view.reaction(for: card) { return reaction.points }
        if let action = card.action { return actionValue(action) }
        return 0
    }

    private static func value(_ card: Card, _ view: AIView) -> Double {
        if view.myHandCount == 1 { return 1000 }   // 最后一张，直接获胜

        var score = Double(immediateValue(card, view))
        let rest = view.hand.filter { $0.uid != card.uid }

        if card.species != nil, view.reaction(for: card) != nil {
            // 倒进去之后容器里剩的那几种物质，才是下家和我下回合要面对的
            let next = view.mixture(afterPlay: card)
            // 下一轮自己还接得住吗
            score += ReactionPotential.answers(in: rest, for: next) > 0 ? 18 : -10
            // 别给下家留一个谁都压得住的混合物
            score -= ReactionPotential.openness(of: next, discard: view.discard) * 60
        } else if let action = card.action {
            if action == .pump || action == .inert, view.opponentHandCounts.contains(where: { $0 <= 2 }) {
                score += 40     // 有人快出完了，先按住他
            }
            if action == .assay { score += view.stockCount > 20 ? 6 : -4 }
            if action == .reversible, view.pendingDraw > 0 { score += 10 }
        }
        return score
    }

    private static func actionValue(_ action: ActionCard) -> Int {
        switch action {
        case .pump: return 8
        case .inert: return 7
        case .reversible: return 4
        case .assay: return 1
        }
    }
}

import XCTest
@testable import ChemCards

/// 共享脚手架：先把随表的 reactions.json 装进 ReactionTable，再提供摆残局的工具。
enum TestBench {

    static let shippedTable = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Data/reactions.json")

    /// static let 惰性求值且只跑一次，多个测试类共用
    static let loadTable: Bool = { (try? ReactionTable.load(url: shippedTable)) != nil }()

    static func species(_ id: String) -> Species {
        guard loadTable, let value = Chemistry.species(id) else { fatalError("物种未登记：\(id)") }
        return value
    }

    static func card(_ id: String, uid: Int) -> Card { Card(species: species(id), uid: uid) }
    static func card(_ action: ActionCard, uid: Int) -> Card { Card(action: action, uid: uid) }

    /// 陪衬牌：KNO₃ 在池子里几乎不反应，适合当「摸上来也没用」的填充
    static func filler(_ count: Int, base: Int = 500) -> [Card] {
        (0..<count).map { Card(species: species("kno3"), uid: base + $0) }
    }

    static func game(hands: [[Card]],
                     top: Card,
                     stock: [Card]? = nil,
                     turn seat: Int = 0,
                     direction: Int = 1,
                     rules: MatchRules = .standard,
                     seed: UInt64 = 1,
                     difficulty: AIDifficulty = .expert) -> GameState {
        let state = GameState(players: MatchSetup.standard(difficulty: difficulty), seed: seed, rules: rules)
        state.install(hands: hands,
                      vessel: [top],
                      stock: stock ?? filler(40),
                      turn: seat,
                      direction: direction)
        return state
    }

    /// 摆一槽混合物：vessel 从最早倒进去的排到最新，Seat 0 先出牌
    static func game(hand: [Card],
                     vessel: [Card],
                     stock: [Card]? = nil,
                     rules: MatchRules = .standard,
                     difficulty: AIDifficulty = .expert) -> GameState {
        let state = GameState(players: MatchSetup.standard(difficulty: difficulty), seed: 1, rules: rules)
        state.install(hands: [hand], vessel: vessel, stock: stock ?? filler(40))
        return state
    }

    static func cardTotal(_ state: GameState) -> Int {
        let hands = state.players.reduce(0) { $0 + $1.handCount }
        return hands + state.stock.count + state.vessel.count
    }

    struct AutoPlayReport {
        var steps = 0
        var rejectedLegalMoves = 0
        var cardTotals = Set<Int>()
        var phase: GamePhase = .playing
    }

    /// 无策略自动对局：有合法牌就随机挑一张，否则摸牌。用来验证状态机不吞牌、不死锁。
    @discardableResult
    static func autoPlay(_ state: GameState, seed: UInt64, maxSteps: Int = 3000) -> AutoPlayReport {
        var rng = SplitMix64(seed: seed)
        var report = AutoPlayReport()
        report.cardTotals.insert(cardTotal(state))
        while !state.phase.isOver && report.steps < maxSteps {
            report.steps += 1
            let moves = state.legalMoves()
            if moves.isEmpty {
                let decision: GameState.Decision = state.canDraw ? .draw : .pass
                if !state.apply(decision) { report.rejectedLegalMoves += 1 }
            } else {
                let pick = moves[rng.nextInt(below: moves.count)]
                if !state.apply(.play(uid: pick.uid)) { report.rejectedLegalMoves += 1 }
            }
            report.cardTotals.insert(cardTotal(state))
        }
        report.phase = state.phase
        return report
    }
}

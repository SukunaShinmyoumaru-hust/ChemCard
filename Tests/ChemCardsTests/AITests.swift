import XCTest
@testable import ChemCards

/// AI 三档的自动对局自检：零非法出牌、零死锁、必然收束，以及「看不到对手手牌」的类型层约束。
final class AITests: XCTestCase {

    private struct Run {
        var steps = 0
        var illegalDecisions = 0
        var passedTurns = 0
        var reactions = 0
        var unfinished = 0
    }

    /// 初级按设计有 12% 概率「有牌可出也先摸一张」，其余两档不该白送一轮
    private func mustAlwaysPlay(_ difficulty: AIDifficulty) -> Bool { difficulty != .novice }

    private func playTable(_ difficulty: AIDifficulty, seed: UInt64) -> Run {
        var run = Run()
        let state = GameState(players: MatchSetup.allAI(difficulty: difficulty), seed: seed)

        while !state.phase.isOver && run.steps <= MatchRules.standard.maxTurns {
            run.steps += 1
            let seat = state.turn
            let legal = Set(state.legalMoves(forSeat: seat).map(\.uid))
            guard let decision = state.aiDecision() else {
                XCTFail("\(difficulty.displayName) 在 AI 回合拿不到决策")
                break
            }
            switch decision {
            case .play(let uid):
                if !legal.contains(uid) { run.illegalDecisions += 1 }
            case .draw:
                if mustAlwaysPlay(difficulty) && !legal.isEmpty { run.illegalDecisions += 1 }
                if !state.canDraw { run.illegalDecisions += 1 }   // 牌堆已空还要摸
            case .pass:
                if !legal.isEmpty || state.canDraw { run.illegalDecisions += 1 }
                run.passedTurns += 1
            }
            if run.illegalDecisions > 0 { break }
            if !state.apply(decision) {
                run.illegalDecisions += 1
                break
            }
        }

        run.unfinished = state.phase.isOver ? 0 : 1
        run.reactions = state.log.filter { $0.reaction != nil }.count
        XCTAssertEqual(TestBench.cardTotal(state), Deck.cardCount, "牌的总数变了")
        return run
    }

    func testEveryTierPlaysFiveHundredCleanGames() {
        XCTAssertTrue(TestBench.loadTable, "随表 reactions.json 没装进来")
        for difficulty in AIDifficulty.allCases {
            var run = Run()
            for seed: UInt64 in 1...500 {
                let result = playTable(difficulty, seed: seed)
                run.steps += result.steps
                run.illegalDecisions += result.illegalDecisions
                run.passedTurns += result.passedTurns
                run.reactions += result.reactions
                run.unfinished += result.unfinished
            }
            XCTAssertEqual(run.illegalDecisions, 0, "\(difficulty.displayName) 出现了非法决策")
            XCTAssertEqual(run.unfinished, 0, "\(difficulty.displayName) 有局在回合上限内没收束")
            XCTAssertGreaterThan(run.reactions, 500, "\(difficulty.displayName) 整批对局几乎没打出反应")
        }
    }

    // MARK: 决策质量（残局断言，避免统计噪声）

    func testExpertTakesTheImmediateWin() {
        let state = TestBench.game(hands: [[TestBench.card("naoh", uid: 1)], TestBench.filler(2, base: 10)],
                                   top: TestBench.card("hcl", uid: 0),
                                   turn: 0,
                                   difficulty: .expert)
        let view = state.aiView(seat: 0)
        var rng = SplitMix64(seed: 3)
        XCTAssertEqual(AIPlanner.decide(for: view, as: .expert, rng: &rng), .play(uid: 1),
                       "手里只剩一张能反应的牌，高级 AI 却没打")
    }

    func testExpertOnlyPlaysWhatActuallyReacts() {
        let state = TestBench.game(hands: [[TestBench.card("nacl", uid: 1), TestBench.card("naoh", uid: 2)]],
                                   top: TestBench.card("hcl", uid: 0),
                                   turn: 0,
                                   difficulty: .expert)
        let view = state.aiView(seat: 0)
        XCTAssertEqual(view.legalMoves.map(\.uid), [2], "NaCl 不该能和盐酸反应")
        var rng = SplitMix64(seed: 3)
        XCTAssertEqual(AIPlanner.decide(for: view, as: .expert, rng: &rng), .play(uid: 2))
    }

    func testNovicePassesSometimesButNeverCheats() {
        let state = TestBench.game(hands: [[TestBench.card("naoh", uid: 1)], TestBench.filler(2, base: 10)],
                                   top: TestBench.card("hcl", uid: 0),
                                   turn: 0,
                                   difficulty: .novice)
        let view = state.aiView(seat: 0)
        var rng = SplitMix64(seed: 7)
        var passes = 0
        for _ in 0..<200 {
            switch AIPlanner.decide(for: view, as: .novice, rng: &rng) {
            case .play(let uid): XCTAssertTrue([1].contains(uid), "初级 AI 打出了不存在的牌")
            case .draw: passes += 1
            case .pass: XCTFail("牌堆还有牌，不该过这一手")
            }
        }
        XCTAssertGreaterThan(passes, 0, "初级的保守摸牌没生效")
        XCTAssertLessThan(passes, 200, "初级光摸牌，一张都不出")
    }

    // MARK: 公开信息约束

    func testAIViewStructurallyCannotSeeOpponentHands() {
        let state = GameState(players: MatchSetup.allAI(difficulty: .expert), seed: 11)
        let view = state.aiView(seat: 0)
        let mine = Set(view.hand.map(\.uid))

        var cardFields: [(String, Set<Int>)] = []
        walk(Mirror(reflecting: view), path: "AIView") { path, value in
            if let cards = value as? [Card] {
                cardFields.append((path, Set(cards.map(\.uid))))
            }
            XCTAssertFalse(String(describing: type(of: value)).contains("Player"),
                           "\(path) 把整个玩家对象交给了 AI")
            XCTAssertFalse(String(describing: type(of: value)).contains("GameState"),
                           "\(path) 把整个游戏状态交给了 AI")
        }

        XCTAssertEqual(cardFields.map(\.0).sorted(),
                       ["AIView.discard", "AIView.hand", "AIView.legalMoves"],
                       "AIView 多出来的 [Card] 字段都可能夹带对手手牌")
        for (path, uids) in cardFields where path.hasSuffix("hand") || path.hasSuffix("legalMoves") {
            XCTAssertTrue(uids.isSubset(of: mine), "\(path) 里出现了不属于我的牌")
        }
        XCTAssertEqual(view.opponentHandCounts.reduce(0, +),
                       state.players.filter { $0.seat != 0 }.reduce(0) { $0 + $1.handCount },
                       "对手手牌数量对不上")
    }

    private func walk(_ mirror: Mirror, path: String, _ visit: (String, Any) -> Void) {
        for child in mirror.children {
            let label = "\(path).\(child.label ?? "?")"
            visit(label, child.value)
            let value = child.value
            if value is Card || value is Species || value is [Card] { continue }
            let nested = Mirror(reflecting: value)
            if nested.displayStyle == .struct || nested.displayStyle == .class {
                walk(nested, path: label, visit)
            }
        }
    }
}

import XCTest
@testable import ChemCards

final class StateMachineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        XCTAssertTrue(TestBench.loadTable, "读不到随表 reactions.json，生成命令：swift run ChemCards --dump-reactions")
    }

    // MARK: 开局

    func testDealtLayout() {
        let state = GameState(players: MatchSetup.standard(difficulty: .expert), seed: 9)
        XCTAssertEqual(state.players.count, 4)
        for player in state.players {
            XCTAssertEqual(player.handCount, MatchRules.standard.handSize, "\(player.name) 手牌数不对")
        }
        XCTAssertEqual(state.vessel.count, 1)
        XCTAssertNotNil(state.vessel[0].species, "容器开局必须是一种物质")
        XCTAssertEqual(state.stock.count, Deck.cardCount - 4 * MatchRules.standard.handSize - 1)
        XCTAssertEqual(TestBench.cardTotal(state), Deck.cardCount)
        XCTAssertEqual(state.turn, 0)
        XCTAssertFalse(state.log.isEmpty, "开局要有记录")
    }

    /// 阵容比座位多，选谁当主角都只能凑出 4 个不重复的人：
    /// 早先 seats() 把「不是你」的角色全排上桌，角色一多就取难度表越界
    func testEveryCharacterSeatsExactlyFourRivals() {
        for human in CharacterID.allCases {
            let players = MatchSetup.seats(human: human, table: .mixed)
            XCTAssertEqual(players.count, MatchSetup.seatCount, "\(human.displayName) 开局人数不对")
            XCTAssertEqual(Set(players.map(\.character)).count, MatchSetup.seatCount,
                           "\(human.displayName) 开局有重复角色")
            XCTAssertEqual(players[0].character, human)
            XCTAssertNil(players[0].difficulty, "0 号位必须是人类")
            XCTAssertEqual(players.dropFirst().compactMap(\.difficulty), TableDifficulty.mixed.seats)
        }
    }

    // MARK: 功能牌推进座位

    func testInertCardSkipsExactlyOneSeat() {
        let state = TestBench.game(hands: [[TestBench.card(.inert, uid: 1), TestBench.card("kno3", uid: 11)]],
                                   top: TestBench.card("hcl", uid: 900))
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.turn, 2, "惰性气氛该跳过下家")
        XCTAssertEqual(state.direction, 1)
    }

    func testReversibleCardFlipsDirection() {
        let state = TestBench.game(hands: [
            [TestBench.card(.reversible, uid: 1), TestBench.card("kno3", uid: 11)],
            [],
            [],
            [TestBench.card("naoh", uid: 2), TestBench.card("kno3", uid: 14)],
        ], top: TestBench.card("hcl", uid: 900))
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.direction, -1)
        XCTAssertEqual(state.turn, 3, "反向后轮到上家")
        XCTAssertTrue(state.apply(.play(uid: 2)))
        XCTAssertEqual(state.turn, 2)
    }

    func testPumpHitsExactlyTheNextSeat() {
        let state = TestBench.game(hands: [
            [TestBench.card(.pump, uid: 1), TestBench.card("naoh", uid: 3)],
            [TestBench.card("caco3", uid: 2)],
        ], top: TestBench.card("hcl", uid: 900))
        let stockBefore = state.stock.count
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.pendingDraw, 0)
        XCTAssertEqual(state.players[1].handCount, 1 + MatchRules.standard.pumpAmount, "下家该被注入两张")
        XCTAssertTrue(state.players[1].hand.contains { $0.uid == 2 })
        XCTAssertEqual(state.stock.count, stockBefore - MatchRules.standard.pumpAmount)
        XCTAssertEqual(state.turn, 2, "被注入的玩家跳过回合")
    }

    func testAssayRevealsStockTop() {
        let state = TestBench.game(hands: [[TestBench.card(.assay, uid: 1), TestBench.card("naoh", uid: 2)]],
                                   top: TestBench.card("hcl", uid: 900))
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.preview.count, ActionCard.assay.previewCount)
        XCTAssertEqual(state.preview.map(\.uid), Array(state.stock.suffix(3).reversed()).map(\.uid))
    }

    // MARK: 「反应!」

    func testCallingReactionSealsTheWin() {
        let state = TestBench.game(hands: [[TestBench.card("naoh", uid: 1)]], top: TestBench.card("hcl", uid: 900))
        XCTAssertTrue(state.needsReactionCall)
        XCTAssertTrue(state.callReaction())
        XCTAssertFalse(state.needsReactionCall, "喊过就不该再催")
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.phase, .finished(winner: 0))
        let first = state.standings().first
        XCTAssertEqual(first?.seat, 0)
        XCTAssertTrue(first?.isWinner == true)
    }

    func testMissedCallCostsAPenaltyCard() {
        let state = TestBench.game(hands: [[TestBench.card("naoh", uid: 1)]], top: TestBench.card("hcl", uid: 900))
        XCTAssertTrue(state.apply(.play(uid: 1)), "漏喊也要先把牌打出去")
        XCTAssertFalse(state.phase.isOver, "漏喊「反应!」不能算赢")
        XCTAssertEqual(state.players[0].handCount, MatchRules.standard.reactionCallPenalty)
        XCTAssertTrue(state.log.contains { $0.text.contains("没喊") })
    }

    func testCallIsRejectedWithoutExactlyOneCard() {
        let state = TestBench.game(hands: [[TestBench.card("naoh", uid: 1), TestBench.card("hcl", uid: 2)]],
                                   top: TestBench.card("hcl", uid: 900))
        XCTAssertFalse(state.callReaction(), "手牌不止一张时不许喊")
    }

    func testExpertAICallsAutomaticallyButNoviceForgets() {
        let sharp = TestBench.game(hands: [[], [TestBench.card("naoh", uid: 1)]],
                                   top: TestBench.card("hcl", uid: 900),
                                   turn: 1,
                                   difficulty: .expert)
        XCTAssertTrue(sharp.apply(.play(uid: 1)))
        XCTAssertEqual(sharp.phase, .finished(winner: 1), "AI 剩一张牌时会自己喊「反应!」")

        var forgetful = MatchRules.standard
        forgetful.noviceForgetCalls = 1
        let sloppy = TestBench.game(hands: [[], [TestBench.card("naoh", uid: 1)]],
                                    top: TestBench.card("hcl", uid: 900),
                                    turn: 1,
                                    rules: forgetful,
                                    difficulty: .novice)
        XCTAssertTrue(sloppy.apply(.play(uid: 1)))
        XCTAssertFalse(sloppy.phase.isOver)
        XCTAssertEqual(sloppy.players[1].handCount, MatchRules.standard.reactionCallPenalty)
    }

    // MARK: 出牌与结算

    /// 氢氧交替进容器，四个人一手接一手都接得上
    func testAlternatingHydrogenAndOxygenKeepsEveryonePlaying() {
        let state = TestBench.game(hands: [
            [TestBench.card("o2", uid: 1), TestBench.card("kno3", uid: 11)],
            [TestBench.card("h2", uid: 2), TestBench.card("kno3", uid: 12)],
            [TestBench.card("o2", uid: 3), TestBench.card("kno3", uid: 13)],
            [TestBench.card("h2", uid: 4), TestBench.card("kno3", uid: 14)],
        ], top: TestBench.card("h2", uid: 900))
        for uid in [1, 2, 3, 4] {
            XCTAssertTrue(state.apply(.play(uid: uid)), "第\(uid)手接不上")
        }
        XCTAssertEqual(state.players.map(\.handCount), [1, 1, 1, 1])
    }

    func testSameCategoryWithoutReactionCannotBePlayed() {
        let state = TestBench.game(hands: [[TestBench.card("kcl", uid: 1)]], top: TestBench.card("nacl", uid: 900))
        XCTAssertFalse(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.players[0].handCount, 1, "打不出去，牌得留在手里")
        XCTAssertNil(state.lastEvent)
    }

    func testBestReactionRecordsThePlayedEquation() {
        let state = TestBench.game(hands: [[TestBench.card("naoh", uid: 1)]], top: TestBench.card("hcl", uid: 900))
        let reaction = ReactionEngine.resolve(Chemistry.species("hcl")!, Chemistry.species("naoh")!)
        XCTAssertNotNil(reaction)
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.best?.reaction.displayEquation, reaction?.displayEquation)
        XCTAssertEqual(state.best?.seat, 0)
        XCTAssertEqual(state.lastEvent?.reaction?.rule, "中和反应")
    }

    // MARK: 牌堆枯竭

    func testRecycleKeepsTheVesselContents() {
        let state = TestBench.game(hands: [[TestBench.card("kno3", uid: 1)]],
                                   top: TestBench.card("hcl", uid: 900),
                                   stock: [])
        // 容器里存着四种物质，只有掉出反应窗口的那一种能回收
        state.install(hands: [[TestBench.card("kno3", uid: 1)]],
                      vessel: [TestBench.card("na2so4", uid: 800),
                               TestBench.card("naoh", uid: 801),
                               TestBench.card("cuso4", uid: 802),
                               TestBench.card("hcl", uid: 900)],
                      stock: [])
        XCTAssertTrue(state.legalMoves().isEmpty)
        XCTAssertTrue(state.canDraw)
        XCTAssertTrue(state.apply(.draw))
        XCTAssertEqual(state.players[0].handCount, 2)
        XCTAssertEqual(state.vessel.count, state.rules.vesselWindow, "回收后只留下还在反应窗口里的物质")
        XCTAssertEqual(state.contents.map(\.id), ["naoh", "cuso4", "hcl"])
        XCTAssertEqual(state.topSpecies?.id, "hcl")
        XCTAssertFalse(state.phase.isOver)
    }

    func testDrawWithEmptyTableStillAdvances() {
        let state = TestBench.game(hands: [[TestBench.card("kno3", uid: 1)]],
                                   top: TestBench.card("hcl", uid: 900),
                                   stock: [])
        XCTAssertFalse(state.canDraw)
        XCTAssertTrue(state.apply(.draw), "摸不到牌也必须把回合交出去，否则卡死")
        XCTAssertEqual(state.turn, 1)
    }

    func testTurnLimitEndsTheMatch() {
        var rules = MatchRules.standard
        rules.maxTurns = 5
        let hands = (0..<4).map { seat in [TestBench.card("kno3", uid: seat + 1)] }
        let state = TestBench.game(hands: hands,
                                   top: TestBench.card("hcl", uid: 900),
                                   rules: rules)
        var steps = 0
        while !state.phase.isOver && steps < 20 {
            XCTAssertTrue(state.apply(.draw))
            steps += 1
        }
        XCTAssertTrue(state.phase.isOver)
        XCTAssertEqual(state.phase, .stalled(turns: 5))
    }

    // MARK: 自动对局

    func testSelfPlayTerminatesWithoutLosingCards() {
        for seed: UInt64 in [1, 17, 42, 99, 2026] {
            let state = GameState(players: MatchSetup.allAI(difficulty: .expert), seed: seed)
            let report = TestBench.autoPlay(state, seed: seed)
            XCTAssertEqual(report.rejectedLegalMoves, 0, "种子 \(seed) 有决策被状态机拒绝")
            XCTAssertEqual(report.cardTotals, [Deck.cardCount], "种子 \(seed) 牌的总数变了")
            XCTAssertTrue(report.phase.isOver, "种子 \(seed) 的 \(report.steps) 步还没打完")
            if case .finished(let winner) = report.phase {
                XCTAssertTrue(state.players[winner].hand.isEmpty, "获胜者手里还有牌")
            }
        }
    }

    func testNoSeatEverGetsStuckWithoutAnEscape() {
        for difficulty in AIDifficulty.allCases {
            let state = GameState(players: MatchSetup.allAI(difficulty: difficulty), seed: 5)
            var steps = 0
            var escapes = 0
            while !state.phase.isOver && steps < 1500 {
                steps += 1
                if state.legalMoves().isEmpty {
                    escapes += 1
                    XCTAssertTrue(state.canDraw, "\(difficulty.displayName) 桌上无牌可出也摸不到牌，死锁")
                }
                _ = TestBench.autoPlay(state, seed: UInt64(steps), maxSteps: 1)
            }
            XCTAssertTrue(state.phase.isOver, "\(difficulty.displayName) 打完前就退出了循环")
            XCTAssertGreaterThan(escapes, 0, "这一局至少该遇到一次无牌可出")
            XCTAssertEqual(TestBench.cardTotal(state), Deck.cardCount)
        }
    }
}

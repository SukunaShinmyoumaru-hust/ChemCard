import XCTest
@testable import ChemCards

final class LegalityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        XCTAssertTrue(TestBench.loadTable, "读不到随表 reactions.json，生成命令：swift run ChemCards --dump-reactions")
    }

    // MARK: 牌堆构成

    func testDeckIs108UniqueCards() {
        var rng = SplitMix64(seed: 7)
        let cards = Deck.build(rng: &rng)
        XCTAssertEqual(cards.count, Deck.cardCount)
        XCTAssertEqual(Deck.chemicalCardCount + Deck.actionCardCount, Deck.cardCount)
        XCTAssertEqual(Set(cards.map(\.uid)).count, cards.count, "uid 必须唯一")
        XCTAssertEqual(cards.filter { $0.species != nil }.count, Deck.chemicalCardCount)
        XCTAssertEqual(cards.filter { $0.action != nil }.count, Deck.actionCardCount)
    }

    func testEveryCardNamesARegisteredSpecies() {
        var rng = SplitMix64(seed: 11)
        for card in Deck.build(rng: &rng) {
            if let species = card.species {
                XCTAssertNotNil(Chemistry.byID[species.id], "\(species.id) 未登记")
            } else {
                XCTAssertNotNil(card.action, "既不是物质也不是功能牌的脏数据")
            }
        }
    }

    func testShuffleIsSeedReproducible() {
        var first = SplitMix64(seed: 3)
        var second = SplitMix64(seed: 3)
        var other = SplitMix64(seed: 4)
        XCTAssertEqual(Deck.build(rng: &first).map(\.uid), Deck.build(rng: &second).map(\.uid))
        XCTAssertNotEqual(Deck.build(rng: &first).map(\.uid), Deck.build(rng: &other).map(\.uid))
    }

    func testActivityScaleStaysInRange() {
        var rng = SplitMix64(seed: 5)
        for card in Deck.build(rng: &rng) {
            XCTAssertTrue((0...9).contains(card.activityScale), "\(card.title) 刻度 \(card.activityScale)")
        }
        XCTAssertEqual(TestBench.card("k", uid: 1).activityScale, 9, "钾最活泼")
        XCTAssertLessThan(TestBench.card("cu", uid: 2).activityScale, TestBench.card("fe", uid: 3).activityScale)
    }

    /// 每张牌至少要有打得出去的对象，否则它永远卡在手里
    func testEverySpeciesIsPlayableSomewhere() {
        var dead: [String] = []
        for species in Chemistry.all {
            let hasPartner = Chemistry.all.contains { other in
                other.id != species.id && ReactionEngine.resolve(species, other) != nil
            }
            if !hasPartner { dead.append(species.id) }
        }
        XCTAssertEqual(dead, [], "这些物种与全表都不反应，成了死牌")
    }

    // MARK: 出牌裁定

    func testLegalityFollowsTheTable() {
        let state = TestBench.game(hands: [[
            TestBench.card("naoh", uid: 1),
            TestBench.card("cu", uid: 2),
            TestBench.card("cuso4", uid: 3),
            TestBench.card("kcl", uid: 4),
        ]], top: TestBench.card("hcl", uid: 900))

        for card in state.players[0].hand {
            let playable = !state.playability(of: card).isIllegal
            let inTable = ReactionEngine.resolve(anyOf: state.contents, with: card.species!) != nil
            XCTAssertEqual(playable, inTable || card.action != nil, "\(card.title) 裁定与表不一致")
        }
    }

    /// 容器是一槽混合物：最新那种接不上也没关系，更早倒进去的那种还活着
    func testAnyLiveSubstanceMakesTheCardPlayable() {
        let state = TestBench.game(hand: [TestBench.card("naoh", uid: 1)],
                                  vessel: [TestBench.card("cuso4", uid: 800), TestBench.card("nacl", uid: 900)])
        XCTAssertEqual(state.contents.map(\.id), ["cuso4", "nacl"])
        let expected = ReactionEngine.resolve(Chemistry.species("cuso4")!, Chemistry.species("naoh")!)
        XCTAssertNotNil(expected, "CuSO₄ + NaOH 不在表里，这条用例失去意义")
        XCTAssertEqual(state.playability(of: state.players[0].hand[0]), .reacts(expected!),
                       "顶牌 NaCl 不反应，但更早的 CuSO₄ 还在槽里，就该打得出去")
    }

    /// 好几种都接得住时，横幅上的方程式取最新倒进去的那一种
    func testNewestSubstanceOwnsTheEquation() {
        let state = TestBench.game(hand: [TestBench.card("naoh", uid: 1)],
                                  vessel: [TestBench.card("hcl", uid: 800), TestBench.card("h2so4", uid: 900)])
        let expected = ReactionEngine.resolve(Chemistry.species("h2so4")!, Chemistry.species("naoh")!)
        XCTAssertNotNil(expected, "H₂SO₄ + NaOH 不在表里，这条用例失去意义")
        XCTAssertEqual(state.playability(of: state.players[0].hand[0]), .reacts(expected!),
                       "两种酸都接得住，方程式该取最新的稀硫酸")
    }

    func testReactionIsTheOnlyWayOut() {
        let state = TestBench.game(hands: [[
            TestBench.card("naoh", uid: 1),
        ]], top: TestBench.card("hcl", uid: 900))
        switch state.playability(of: state.players[0].hand[0]) {
        case .reacts(let reaction): XCTAssertEqual(reaction.rule, "中和反应")
        default: XCTFail("NaOH 打在盐酸上应当中和：\(state.playability(of: state.players[0].hand[0]))")
        }

        // 同类别不再算打出，接不上只能摸牌
        let mixState = TestBench.game(hands: [[
            TestBench.card("kcl", uid: 1),
        ]], top: TestBench.card("nacl", uid: 900))
        let verdict = mixState.playability(of: mixState.players[0].hand[0])
        guard case .illegal(let reason) = verdict else { return XCTFail("同类别不该打得出去：\(verdict)") }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertTrue(mixState.canDraw, "牌堆还有牌时靠摸牌脱身")
    }

    /// 牌堆也空了、一张都接不上：必须能过牌，状态机不能卡死
    func testPassingWhenNothingIsPlayable() {
        let state = TestBench.game(hands: [[TestBench.card("kcl", uid: 1)]],
                                  top: TestBench.card("nacl", uid: 900),
                                  stock: [])
        XCTAssertFalse(state.canDraw)
        XCTAssertTrue(state.mustPass)
        XCTAssertTrue(state.apply(.pass))
        XCTAssertEqual(state.turn, 1, "过牌之后轮到下家")
    }

    func testIllegalPlayCarriesTeachingReason() {
        let state = TestBench.game(hands: [[TestBench.card("cu", uid: 1)]], top: TestBench.card("hcl", uid: 900))
        let verdict = state.playability(of: state.players[0].hand[0])
        guard case .illegal(let reason) = verdict else { return XCTFail("Cu + 盐酸 必须非法") }
        XCTAssertTrue(reason.contains("氢"), "原因应讲明活动性顺序，实际：\(reason)")
        XCTAssertFalse(state.apply(.play(uid: 1)), "非法出牌不能被接受")
    }

    func testActionCardsAreAlwaysLegalAndDoNotChangeContents() {
        let state = TestBench.game(hands: [[TestBench.card(.assay, uid: 1)]], top: TestBench.card("hcl", uid: 900))
        XCTAssertEqual(state.playability(of: state.players[0].hand[0]), .action(.assay))
        let before = state.topSpecies
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.topSpecies?.id, before?.id, "检液不改变容器里的物质")
        XCTAssertEqual(state.vessel.last?.action, .assay)
    }

    func testLegalMovesOnlyForCurrentSeat() {
        let state = TestBench.game(hands: [[TestBench.card("naoh", uid: 1)], [TestBench.card("naoh", uid: 2)]],
                                   top: TestBench.card("hcl", uid: 900))
        XCTAssertEqual(state.legalMoves(forSeat: 0).count, 1)
        XCTAssertTrue(state.legalMoves(forSeat: 1).isEmpty, "没轮到的座位不该有出牌权")
    }

    // MARK: AI 视角的信息边界

    func testAIViewCarriesNoHiddenCards() {
        let state = GameState(players: MatchSetup.standard(difficulty: .expert), seed: 21)
        let view = state.aiView(seat: 2)
        let visible = Set(view.hand.map(\.uid)).union(view.discard.map(\.uid))
        var leaked: [Int] = []
        walk(view, depth: 0) { uid in
            if !visible.contains(uid) { leaked.append(uid) }
        }
        XCTAssertEqual(leaked, [], "AIView 里出现了不属于自己也不是弃牌堆的牌")
        XCTAssertEqual(view.myHandCount, state.players[2].handCount)
        XCTAssertEqual(view.opponentHandCounts.count, 3)
    }

    private func walk(_ value: Any, depth: Int, report: (Int) -> Void) {
        if depth > 4 { return }
        if let cards = value as? [Card] {
            cards.forEach { report($0.uid) }
            return
        }
        for child in Mirror(reflecting: value).children {
            walk(child.value, depth: depth + 1, report: report)
        }
    }
}

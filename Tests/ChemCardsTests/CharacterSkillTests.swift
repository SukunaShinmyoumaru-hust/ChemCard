import XCTest
@testable import ChemCards

/// 角色技能：一局一次，只有人类能按。
/// 三个「等价」技能的断言对象是那张对应的功能牌，不是硬编码的数字——功能牌改了技能就得跟着改。
final class CharacterSkillTests: XCTestCase {

    override func setUp() {
        super.setUp()
        XCTAssertTrue(TestBench.loadTable, "读不到随表 reactions.json")
    }

    /// 换一个主角摆残局：0 号位是人类，其余三家按阵容轮转
    private func table(human: CharacterID,
                       hand: [Card],
                       vessel: [Card],
                       stock: [Card]? = nil,
                       rules: MatchRules = .standard) -> GameState {
        let state = GameState(players: MatchSetup.seats(human: human, table: .mixed), seed: 1, rules: rules)
        state.install(hands: [hand], vessel: vessel, stock: stock ?? TestBench.filler(40))
        return state
    }

    // MARK: 与功能牌等价

    func testMiracleSettlesLikeThePumpCard() {
        let withSkill = table(human: .sanae, hand: [TestBench.card("kno3", uid: 11)],
                              vessel: [TestBench.card("hcl", uid: 900)])
        let withCard = table(human: .sanae, hand: [TestBench.card(.pump, uid: 11),
                                                   TestBench.card("kno3", uid: 12)],
                             vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(withSkill.useSkill())
        XCTAssertTrue(withCard.apply(.play(uid: 11)))
        XCTAssertEqual(withSkill.turn, withCard.turn, "下家同样是吃了牌又跳过")
        XCTAssertEqual(withSkill.pendingDraw, withCard.pendingDraw)
        XCTAssertEqual(withSkill.players[1].handCount, withCard.players[1].handCount)
        XCTAssertEqual(withSkill.turn, 2)
    }

    func testDreamSealSettlesLikeTheInertCard() {
        let withSkill = table(human: .reimu, hand: [TestBench.card("kno3", uid: 11)],
                              vessel: [TestBench.card("hcl", uid: 900)])
        let withCard = table(human: .reimu, hand: [TestBench.card(.inert, uid: 11),
                                                   TestBench.card("kno3", uid: 12)],
                             vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(withSkill.useSkill())
        XCTAssertTrue(withCard.apply(.play(uid: 11)))
        XCTAssertEqual(withSkill.turn, withCard.turn)
        XCTAssertEqual(withSkill.direction, withCard.direction)
        XCTAssertEqual(withSkill.turn, 2, "下家跳过一回合")
    }

    func testReversalSettlesLikeTheReversibleCard() {
        let withSkill = table(human: .seiga, hand: [TestBench.card("kno3", uid: 11)],
                              vessel: [TestBench.card("hcl", uid: 900)])
        let withCard = table(human: .seiga, hand: [TestBench.card(.reversible, uid: 11),
                                                   TestBench.card("kno3", uid: 12)],
                             vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(withSkill.useSkill())
        XCTAssertTrue(withCard.apply(.play(uid: 11)))
        XCTAssertEqual(withSkill.direction, withCard.direction)
        XCTAssertEqual(withSkill.turn, withCard.turn)
        XCTAssertEqual(withSkill.direction, -1, "出牌方向反向")
    }

    // MARK: 一局一次

    func testSkillIsSpentForTheRestOfTheMatch() {
        let state = table(human: .sanae, hand: [TestBench.card("kno3", uid: 11)],
                          vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(state.canUseSkill)
        XCTAssertTrue(state.useSkill())
        XCTAssertFalse(state.canUseSkill, "本局已经用过")
        XCTAssertFalse(state.useSkill(), "第二次按不该有效果")
    }

    func testAiNeverGetsASkill() {
        let state = table(human: .cirno, hand: [TestBench.card("kno3", uid: 11)],
                          vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(state.useSkill())
        XCTAssertEqual(state.turn, 1)
        XCTAssertFalse(state.canUseSkill, "轮到 AI 时技能按钮不能亮")
        XCTAssertFalse(state.useSkill(), "AI 不许发动技能")
    }

    // MARK: 魔炮

    func testMasterSparkLoadsTheTopStockSubstance() {
        let state = table(human: .marisa,
                          hand: [TestBench.card("kno3", uid: 11)],
                          vessel: [TestBench.card("hcl", uid: 900)],
                          stock: TestBench.filler(3) + [TestBench.card("na2co3", uid: 700)])
        let total = TestBench.cardTotal(state)
        XCTAssertTrue(state.useSkill())
        XCTAssertEqual(state.topSpecies?.id, "na2co3", "容器顶上该是牌堆最上面那种物质")
        XCTAssertEqual(state.contents.map(\.id), ["hcl", "na2co3"])
        XCTAssertEqual(TestBench.cardTotal(state), total, "魔炮只是搬牌，不许凭空造一张")
        XCTAssertEqual(state.turn, 1, "放完魔炮这一手就交出去")
    }

    /// 窗口满了之后，魔炮轰进去的那一张会把最早那种挤出去——这正是它值钱的地方
    func testMasterSparkSqueezesTheOldestSubstanceOut() {
        let state = table(human: .marisa,
                          hand: [TestBench.card("kno3", uid: 11)],
                          vessel: [TestBench.card("naoh", uid: 800),
                                   TestBench.card("cuso4", uid: 801),
                                   TestBench.card("hcl", uid: 900)],
                          stock: [TestBench.card("na2co3", uid: 700)])
        XCTAssertTrue(state.useSkill())
        XCTAssertEqual(state.contents.map(\.id), ["cuso4", "hcl", "na2co3"])
        XCTAssertEqual(state.vessel.count, 4, "被挤出窗口的牌还压在弃牌堆底下，等回收")
    }

    /// 牌堆和弃牌堆都榨不出物质牌时，魔炮按不动，也不能算用掉一次
    func testMasterSparkDoesNotFireWithoutAReplacement() {
        let state = table(human: .marisa,
                          hand: [TestBench.card("kno3", uid: 11)],
                          vessel: [TestBench.card(.pump, uid: 900)],
                          stock: [])
        XCTAssertFalse(state.canUseSkill)
        XCTAssertFalse(state.useSkill())
        XCTAssertFalse(state.players[0].skillUsed, "打空的技能不能白扣")
    }

    // MARK: The World

    func testPerfectTimeAllowsTwoPlaysInOneTurn() {
        let state = table(human: .sakuya,
                          hand: [TestBench.card("naoh", uid: 1), TestBench.card("naoh", uid: 2),
                                 TestBench.card("kno3", uid: 3)],
                          vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(state.useSkill())
        XCTAssertEqual(state.turn, 0, "发动技能本身不占一手")
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.turn, 0, "双发之后还轮到自己")
        XCTAssertTrue(state.apply(.play(uid: 2)))
        XCTAssertEqual(state.turn, 1, "第二张照常交棒")
        XCTAssertEqual(state.players[0].handCount, 1)
    }

    /// 双发不能把「跳过下家」吞掉：那张功能牌的效果顺延到多出来的那一手之后生效
    func testPerfectTimeDefersTheSkip() {
        let state = table(human: .sakuya,
                          hand: [TestBench.card(.inert, uid: 1), TestBench.card("naoh", uid: 2),
                                 TestBench.card("kno3", uid: 3)],
                          vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(state.useSkill())
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertEqual(state.turn, 0, "双发还轮到自己，跳过先记在下家身上")
        XCTAssertEqual(state.players[1].frozen, 1)
        XCTAssertTrue(state.apply(.play(uid: 2)))
        XCTAssertEqual(state.turn, 2, "那一手惰性气氛不许因为双发就凭空消失")
    }

    // MARK: 完美冻结

    func testIceBurySkipsTheUserOnTheNextRound() {
        let state = table(human: .cirno, hand: [TestBench.card("kno3", uid: 11)],
                          vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(state.useSkill())
        XCTAssertEqual(state.turn, 1)
        XCTAssertEqual(state.players[0].frozen, 1)
        for _ in 1...3 { XCTAssertTrue(state.apply(.draw)) }
        XCTAssertEqual(state.turn, 1, "琪露诺那一格被冰吃掉，直接推到再下一家")
        XCTAssertEqual(state.players[0].frozen, 0)
        XCTAssertTrue(state.log.contains { $0.text.contains("动不了") })
    }

    // MARK: 万解诊断

    func testDiagnosisRevealsOnlyForThisTurn() {
        let state = table(human: .eirin, hand: [TestBench.card("naoh", uid: 1),
                                                TestBench.card("kno3", uid: 2)],
                          vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertFalse(state.hintArmed, "平时不许把答案摊开")
        XCTAssertTrue(state.useSkill())
        XCTAssertTrue(state.hintArmed)
        XCTAssertTrue(state.apply(.play(uid: 1)))
        XCTAssertFalse(state.hintArmed, "交棒之后提示要灭")
    }

    // MARK: 摆局与恢复

    func testInstallClearsSkillState() {
        let state = table(human: .cirno, hand: [TestBench.card("kno3", uid: 11)],
                          vessel: [TestBench.card("hcl", uid: 900)])
        XCTAssertTrue(state.useSkill())
        state.install(hands: [[TestBench.card("naoh", uid: 21)]],
                      vessel: [TestBench.card("hcl", uid: 900)],
                      stock: TestBench.filler(40))
        XCTAssertFalse(state.players[0].skillUsed)
        XCTAssertEqual(state.players[0].frozen, 0)
        XCTAssertEqual(state.bonusPlay, 0)
    }
}

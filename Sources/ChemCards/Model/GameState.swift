import Combine

/// 回合状态机。出牌合法性由 ReactionTable 裁定，跳牌/反向/注液泵/「反应!」在这里推进。
final class GameState: ObservableObject {

    enum Decision: Equatable {
        case play(uid: Int)
        case draw
        /// 一张都打不出、牌堆也空了：过这一手
        case pass
    }

    /// 本局最漂亮的一次反应，结算面板用
    struct BestReaction: Equatable {
        let seat: Int
        let reaction: Reaction
    }

    /// 一次出牌的结果，横幅与立绘情绪用
    struct PlayEvent: Equatable {
        let seat: Int
        let card: Card
        let reaction: Reaction?
    }

    @Published private(set) var players: [Player]
    @Published private(set) var stock: [Card] = []
    @Published private(set) var vessel: [Card] = []
    @Published private(set) var turn = 0
    @Published private(set) var direction = 1
    @Published private(set) var pendingDraw = 0
    @Published private(set) var phase: GamePhase = .playing
    @Published private(set) var log: [GameLogEntry] = []
    @Published private(set) var preview: [Card] = []
    @Published private(set) var lastEvent: PlayEvent?
    @Published private(set) var best: BestReaction?

    let rules: MatchRules
    private var rng: SplitMix64
    private var turnsPlayed = 0
    private var logSequence = 0

    init(players: [Player], seed: UInt64 = MatchRules.defaultSeed, rules: MatchRules = .standard) {
        self.rules = rules
        self.rng = SplitMix64(seed: seed)
        self.players = players.map { seat in
            var fresh = seat
            fresh.hand = []
            fresh.calledReaction = false
            return fresh
        }
        deal()
    }

    private func deal() {
        var pile = Deck.build(rng: &rng)
        for _ in 0..<rules.handSize {
            for seat in players.indices where !pile.isEmpty {
                players[seat].hand.append(pile.removeLast())
            }
        }
        // 容器里先放一种物质，保证第一手就有可反应的顶牌
        if let index = pile.lastIndex(where: { $0.species != nil }) {
            vessel.append(pile.remove(at: index))
        }
        stock = pile
        record(seat: turn, text: "发牌完毕，每人\(rules.handSize)张。容器中已有\(topSpecies?.name ?? "（空）")，\(currentPlayer.name) 先出牌。")
    }

    // MARK: 桌面状态

    var seatCount: Int { players.count }
    var currentPlayer: Player { players[turn] }
    var topCard: Card? { vessel.last }

    /// 容器里现存的物质：功能牌不改变它，倒进去的试剂也还在，最近这几种都能拿去反应
    var contents: [Species] {
        guard let start = oldestContentsIndex else { return [] }
        return vessel[start...].compactMap(\.species)
    }

    /// 最新倒进去的那一种
    var topSpecies: Species? { vessel.last(where: { $0.species != nil })?.species }

    /// 容器里现存物质对应的牌，最早到最新：界面只画这些，用掉的旧牌不算内容物
    var vesselCards: [Card] {
        guard let start = oldestContentsIndex else { return [] }
        return vessel[start...].filter { $0.species != nil }
    }

    /// 还在反应窗口里的最早那种物质的位置：压在它上面的旧牌都可以回收重洗
    private var oldestContentsIndex: Int? {
        let indexes = vessel.indices.filter { vessel[$0].species != nil }
        return indexes.isEmpty ? nil : indexes.suffix(rules.vesselWindow).first
    }

    var isHumanTurn: Bool { currentPlayer.isHuman }

    /// 该不该给玩家弹出「反应!」按钮
    var needsReactionCall: Bool {
        phase == .playing && currentPlayer.isHuman
            && currentPlayer.handCount == rules.reactionCallThreshold
            && !currentPlayer.calledReaction
    }

    var directionText: String { direction > 0 ? "顺时针" : "逆时针" }

    /// 还能不能摸牌（牌堆空了但容器里有旧牌可回收时也算能）
    var canDraw: Bool {
        guard phase == .playing else { return false }
        if !stock.isEmpty { return true }
        guard let index = oldestContentsIndex else { return false }
        return index > 0
    }

    /// 一张都打不出、牌堆也空了，只能过这一手
    var mustPass: Bool {
        guard phase == .playing, !canDraw else { return false }
        return legalMoves().isEmpty
    }

    // MARK: 裁定

    func playability(of card: Card) -> Playability {
        playability(of: card, forSeat: turn)
    }

    func playability(of card: Card, forSeat seat: Int) -> Playability {
        guard !phase.isOver else { return .illegal(reason: "本局已经结束") }
        guard seat == turn else { return .illegal(reason: "还没轮到\(players[seat].name)") }
        guard players[seat].hand.contains(where: { $0.uid == card.uid }) else {
            return .illegal(reason: "这张牌不在\(players[seat].name)手里")
        }
        if let action = card.action { return .action(action) }
        guard let species = card.species else { return .illegal(reason: "无法识别的牌") }
        let mixture = contents
        guard !mixture.isEmpty else { return .illegal(reason: "反应容器里没有物质") }
        if let reaction = ReactionEngine.resolve(anyOf: mixture, with: species) { return .reacts(reaction) }
        return .illegal(reason: ReactionEngine.explain(contents: mixture, candidate: species))
    }

    func legalMoves() -> [Card] { legalMoves(forSeat: turn) }

    func legalMoves(forSeat seat: Int) -> [Card] {
        guard !phase.isOver, seat == turn else { return [] }
        return players[seat].hand.filter { !playability(of: $0, forSeat: seat).isIllegal }
    }

    // MARK: 行动

    /// 执行当前回合玩家的决策，返回是否被接受
    @discardableResult
    func apply(_ decision: Decision) -> Bool {
        guard !phase.isOver else { return false }
        if !currentPlayer.isHuman { autoCallForAI(seat: turn) }
        switch decision {
        case .draw:
            return drawAndPass()
        case .pass:
            return passTurn()
        case .play(let uid):
            guard let card = players[turn].hand.first(where: { $0.uid == uid }) else { return false }
            let verdict = playability(of: card)
            guard !verdict.isIllegal else { return false }
            perform(card, verdict)
            return true
        }
    }

    /// 喊「反应!」：只有轮到自己、且手里正好剩一张时有效
    @discardableResult
    func callReaction() -> Bool {
        guard !phase.isOver else { return false }
        let seat = turn
        guard players[seat].handCount == rules.reactionCallThreshold, !players[seat].calledReaction else { return false }
        players[seat].calledReaction = true
        record(seat: seat, text: "\(players[seat].name) 喊了「反应!」")
        return true
    }

    private func perform(_ card: Card, _ verdict: Playability) {
        let seat = turn
        players[seat].hand.removeAll { $0.uid == card.uid }
        vessel.append(card)
        var skipped = 0

        switch verdict {
        case .reacts(let reaction):
            lastEvent = PlayEvent(seat: seat, card: card, reaction: reaction)
            // reaction.points 只是反应表里的权重，用来挑本局最漂亮的一次，不当分数用
            if best == nil || reaction.points > best!.reaction.points {
                best = BestReaction(seat: seat, reaction: reaction)
            }
            record(seat: seat,
                   text: "\(players[seat].name) 打出\(card.title)：\(reaction.displayEquation)；\(reaction.phenomenonText)",
                   reaction: reaction)
        case .action(let action):
            lastEvent = PlayEvent(seat: seat, card: card, reaction: nil)
            switch action {
            case .pump:
                pendingDraw += rules.pumpAmount
                record(seat: seat, text: "\(players[seat].name) 使用注液泵：下家摸\(rules.pumpAmount)张并跳过回合")
            case .inert:
                skipped = 1
                record(seat: seat, text: "\(players[seat].name) 营造惰性气氛：下家跳过一回合")
            case .reversible:
                direction *= -1
                record(seat: seat, text: "\(players[seat].name) 声明可逆反应：出牌改为\(directionText)")
            case .assay:
                preview = Array(stock.suffix(action.previewCount).reversed())
                let names = preview.map(\.title).joined(separator: "、")
                record(seat: seat, text: "\(players[seat].name) 检液：牌堆顶是\(names.isEmpty ? "（已空）" : names)")
            }
        case .illegal:
            return
        }

        if players[seat].hand.isEmpty {
            guard players[seat].calledReaction else {
                let penalty = drawCards(seat: seat, count: rules.reactionCallPenalty)
                record(seat: seat, text: "\(players[seat].name) 打出最后一张牌却没喊「反应!」，罚抽\(penalty)张")
                advanceTurn(skipping: skipped)
                return
            }
            phase = .finished(winner: seat)
            record(seat: seat, text: "\(players[seat].name) 出完手牌，胜利！")
            return
        }
        advanceTurn(skipping: skipped)
    }

    private func drawAndPass() -> Bool {
        let seat = turn
        let got = drawCards(seat: seat, count: 1)
        guard got > 0 else { return passTurn() }
        record(seat: seat, text: "\(players[seat].name) 从牌堆摸了\(got)张牌")
        advanceTurn(skipping: 0)
        return true
    }

    private func passTurn() -> Bool {
        let seat = turn
        record(seat: seat, text: "\(players[seat].name) 一张都接不上，本回合过")
        advanceTurn(skipping: 0)
        return true
    }

    @discardableResult
    private func drawCards(seat: Int, count: Int) -> Int {
        var drawn = 0
        for _ in 0..<count {
            if stock.isEmpty { recycleVessel() }
            guard let card = stock.popLast() else { break }
            players[seat].hand.append(card)
            drawn += 1
        }
        if players[seat].handCount > rules.reactionCallThreshold {
            players[seat].calledReaction = false
        }
        return drawn
    }

    /// 弃牌堆回收成牌堆：容器里现存的这几种物质（以及压在它们上面的功能牌）留下，更早的倒回牌堆
    private func recycleVessel() {
        guard let index = oldestContentsIndex, index > 0 else { return }
        let recycled = Array(vessel[0..<index])
        vessel = Array(vessel[index...])
        stock = recycled.shuffled(using: &rng)
        record(seat: turn, text: "把弃牌堆的\(recycled.count)张牌重新洗回牌堆")
    }

    private func advanceTurn(skipping: Int) {
        var next = turn
        for _ in 0..<(1 + skipping) {
            next = (next + direction + seatCount) % seatCount
        }
        turn = next
        turnsPlayed += 1
        if turnsPlayed >= rules.maxTurns {
            stall()
            return
        }
        guard pendingDraw > 0 else { return }
        let amount = pendingDraw
        pendingDraw = 0
        let got = drawCards(seat: turn, count: amount)
        record(seat: turn, text: "\(currentPlayer.name) 被注液泵注入\(got)张牌，跳过本回合")
        turn = (turn + direction + seatCount) % seatCount
        turnsPlayed += 1
        if turnsPlayed >= rules.maxTurns { stall() }
    }

    private func stall() {
        phase = .stalled(turns: turnsPlayed)
        record(seat: turn, text: "打了\(turnsPlayed)手还没人出完，按剩牌数结算")
    }

    /// AI 在自己回合开始、手里只剩一张时喊「反应!」，初级 AI 会按概率忘记
    private func autoCallForAI(seat: Int) {
        let player = players[seat]
        guard player.handCount == rules.reactionCallThreshold, !player.calledReaction else { return }
        let forgets = player.difficulty == .novice && rng.nextUnit() < rules.noviceForgetCalls
        guard !forgets else { return }
        players[seat].calledReaction = true
        record(seat: seat, text: "\(player.name) 喊了「反应!」")
    }

    private func record(seat: Int, text: String, reaction: Reaction? = nil) {
        logSequence += 1
        log.append(GameLogEntry(id: logSequence, seat: seat, text: text, reaction: reaction))
    }

    // MARK: 结算

    /// 名次：先出完的人第一，其余按手里剩几张排
    func standings() -> [Standing] {
        let winner = phase.winner
        let ordered = players.sorted { a, b in
            if a.seat == winner { return true }
            if b.seat == winner { return false }
            return a.handCount != b.handCount ? a.handCount < b.handCount : a.seat < b.seat
        }
        return ordered.enumerated().map { entry in
            Standing(rank: entry.offset + 1,
                     seat: entry.element.seat,
                     name: entry.element.name,
                     cardsLeft: entry.element.handCount,
                     isWinner: entry.element.handCount == 0)
        }
    }

    // MARK: 摆局

    /// 把桌面摆成指定状态：单元测试构造残局、存档恢复用
    func install(hands: [[Card]],
                 vessel: [Card],
                 stock: [Card],
                 turn seat: Int = 0,
                 direction: Int = 1) {
        for index in players.indices {
            players[index].hand = index < hands.count ? hands[index] : []
            players[index].calledReaction = false
        }
        self.vessel = vessel
        self.stock = stock
        self.turn = seat % seatCount
        self.direction = direction
        self.pendingDraw = 0
        self.phase = .playing
        self.turnsPlayed = 0
    }

    // MARK: AI 视角

    /// 只暴露公开信息：自己的手牌、容器、弃牌堆、各家剩牌数、牌堆张数、合法着法
    func aiView(seat: Int) -> AIView {
        AIView(seat: seat,
               hand: players[seat].hand,
               contents: contents,
               window: rules.vesselWindow,
               discard: vessel,
               handCounts: players.map(\.handCount),
               stockCount: stock.count,
               pendingDraw: pendingDraw,
               isMyTurn: seat == turn,
               canDraw: canDraw,
               legalMoves: seat == turn ? legalMoves(forSeat: seat) : [])
    }

    /// 轮到 AI 时由它自己决策；人类的回合返回 nil
    func aiDecision() -> Decision? {
        guard !phase.isOver, let difficulty = currentPlayer.difficulty else { return nil }
        return AIPlanner.decide(for: aiView(seat: turn), as: difficulty, rng: &rng)
    }
}

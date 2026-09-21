import AppKit
import Combine
import SwiftUI

/// 舞台导演：所有桌面操作都从这里进模型，再把模型事件翻译成横幅、台词、情绪和提示气泡。
/// AI 时钟也在这里跑，视图只负责画。
final class StageDirector: ObservableObject {

    struct Hint: Equatable {
        let seat: Int
        let text: String
    }

    let state: GameState

    @Published private(set) var banner: GameState.PlayEvent?
    @Published private(set) var speech: [Int: String] = [:]
    @Published private(set) var moods: [Int: RigMood] = [:]
    @Published private(set) var hint: Hint?
    @Published var showLog = false
    @Published var showResult = false

    /// 出牌节奏：AI 每一手至少留给玩家读完方程式的时间
    enum PlayPace: String, CaseIterable, Identifiable {
        case relaxed, normal, brisk

        var id: String { rawValue }

        var label: String {
            switch self {
            case .relaxed: return "舒缓"
            case .normal: return "标准"
            case .brisk: return "爽快"
            }
        }

        /// 一手牌的最短停留
        var beat: TimeInterval {
            switch self {
            case .relaxed: return 2.5
            case .normal: return 1.8
            case .brisk: return 1.15
            }
        }

        var bannerHold: TimeInterval { beat * 2.3 }
        var speechHold: TimeInterval { beat * 1.5 }
    }

    @Published var pace: PlayPace = .normal {
        didSet { busyUntil = Date() }     // 切档立刻作用到下一拍
    }

    private var cancellables = Set<AnyCancellable>()
    private var bannerTask: DispatchWorkItem?
    private var speechTasks: [Int: DispatchWorkItem] = [:]
    private var moodTasks: [Int: DispatchWorkItem] = [:]
    private var hintTask: DispatchWorkItem?
    private var busyUntil = Date.distantPast
    private var seenEvent: GameState.PlayEvent?
    private var seenPhase: GamePhase = .playing

    private let reduceMotion: Bool

    init(players: [Player],
         seed: UInt64 = MatchRules.defaultSeed,
         rules: MatchRules = .standard,
         pace: PlayPace = .normal,
         reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
        self.state = GameState(players: players, seed: seed, rules: rules)
        self.pace = pace
        self.reduceMotion = reduceMotion
        start()
    }

    // MARK: 时钟

    private func start() {
        // 细粒度轮询 + busyUntil 门控，切节奏档能立刻生效
        Timer.publish(every: 0.12, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)

        // objectWillChange 发在写入之前，所以推一拍到下一个 runloop 再读模型
        state.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.sync() }
            }
            .store(in: &cancellables)
    }

    private func tick() {
        guard !state.phase.isOver, !state.isHumanTurn, Date() >= busyUntil else { return }
        guard let decision = state.aiDecision() else { return }
        let seat = state.turn
        state.apply(decision)
        switch decision {
        case .play:
            break                       // 出牌走 banner/sync 那条演出线
        case .draw:
            busyUntil = Date() + pace.beat * 0.62
            setMood(seat, .draw)
            say(seat, PhraseBook.line(for: state.players[seat].character, .drawn,
                                      context: PhraseBook.Context(seed: state.stock.count)))
        case .pass:
            busyUntil = Date() + pace.beat * 0.62
            setMood(seat, .pressed)
            say(seat, PhraseBook.line(for: state.players[seat].character, .passed,
                                      context: PhraseBook.Context(seed: seat)))
        }
    }

    // MARK: 演出

    private func sync() {
        if let event = state.lastEvent, event != seenEvent {
            seenEvent = event
            present(event)
        }
        if state.phase != seenPhase {
            seenPhase = state.phase
            presentPhase(state.phase)
        }
    }

    private func present(_ event: GameState.PlayEvent) {
        let seat = event.seat
        let reaction = event.reaction
        let context = PhraseBook.Context(species: event.card.title,
                                         equation: reaction?.displayEquation ?? "",
                                         seed: event.card.uid)

        banner = event
        bannerTask?.cancel()
        if banner != nil {
            let clear = DispatchWorkItem { [weak self] in self?.banner = nil }
            bannerTask = clear
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? pace.bannerHold * 1.4
                                                                           : pace.bannerHold), execute: clear)
        }
        busyUntil = Date() + pace.beat * (reaction != nil ? 1 : 0.7)

        // 现象越多、越是高中层的反应，这一发越值得得意
        let showy = reaction.map { $0.phenomena.count >= 2 || $0.tier == .senior } ?? false
        setMood(seat, showy ? .win : .play)
        if showy {
            for other in 0..<state.seatCount where other != seat { setMood(other, .pressed) }
        }

        say(seat, PhraseBook.line(for: state.players[seat].character,
                                  showy ? .bigPlay : .play,
                                  context: context))
    }

    private func presentPhase(_ phase: GamePhase) {
        bannerTask?.cancel()
        banner = nil
        switch phase {
        case .playing:
            break
        case .finished(let winner):
            setMood(winner, .win)
            say(winner, PhraseBook.line(for: state.players[winner].character, .win), hold: 8)
            showResult = true
        case .stalled:
            showResult = true
        }
    }

    private func setMood(_ seat: Int, _ mood: RigMood) {
        guard seat < state.seatCount else { return }
        moods[seat] = mood
        moodTasks[seat]?.cancel()
        let clear = DispatchWorkItem { [weak self] in self?.moods[seat] = .idle }
        moodTasks[seat] = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: clear)
    }

    func say(_ seat: Int, _ text: String, hold: Double? = nil) {
        guard seat < state.seatCount else { return }
        speech[seat] = text
        speechTasks[seat]?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.speech[seat] = nil }
        speechTasks[seat] = task
        DispatchQueue.main.asyncAfter(deadline: .now() + (hold ?? pace.speechHold), execute: task)
    }

    private func showHint(_ newHint: Hint, hold: Double = 4.0) {
        hint = newHint
        hintTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.hint = nil }
        hintTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + hold, execute: task)
    }

    // MARK: 操作入口

    func play(_ card: Card) {
        guard state.phase == .playing else { return }
        guard state.isHumanTurn else {
            // 点了没反应最容易被当成卡死，必须说清楚是谁还在出牌
            showHint(Hint(seat: 0, text: "还没轮到你，\(state.currentPlayer.name) 正在出牌"))
            return
        }
        let verdict = state.playability(of: card)
        guard !verdict.isIllegal else {
            if case .illegal(let reason) = verdict {
                showHint(Hint(seat: state.turn, text: reason))
                setMood(state.turn, .pressed)
                say(state.turn,
                    PhraseBook.line(for: state.currentPlayer.character, .illegal,
                                    context: PhraseBook.Context(species: card.title, seed: card.uid)))
            }
            return
        }
        state.apply(.play(uid: card.uid))
    }

    func draw() {
        guard state.phase == .playing, state.isHumanTurn else { return }
        guard state.canDraw else { pass(); return }
        setMood(state.turn, .draw)
        say(state.turn,
            PhraseBook.line(for: state.currentPlayer.character, .drawn,
                            context: PhraseBook.Context(seed: state.stock.count)))
        state.apply(.draw)
    }

    /// 一张都打不出、牌堆也空了：过这一手
    func pass() {
        guard state.phase == .playing, state.isHumanTurn, state.mustPass else { return }
        setMood(state.turn, .pressed)
        say(state.turn, "接不上……过")
        state.apply(.pass)
    }

    /// 轮到自己且牌堆/弃牌堆还有牌就能主动摸一张（UNO 式的自愿摸牌）
    var canDrawCard: Bool {
        state.phase == .playing && state.isHumanTurn && state.canDraw
    }

    var canPassTurn: Bool { state.mustPass && state.isHumanTurn }

    @discardableResult
    func callReaction() -> Bool {
        guard state.needsReactionCall else { return false }
        let ok = state.callReaction()
        if ok { say(0, "反应！", hold: 2.0) }
        return ok
    }

    func dismissBanner() {
        bannerTask?.cancel()
        banner = nil
    }
}

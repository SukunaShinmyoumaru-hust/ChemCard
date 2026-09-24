import AppKit
import SwiftUI

/// 无头渲染：`ChemCards --render /tmp/shot.png table` 直接把界面画成 PNG。
/// 系统没给终端「屏幕录制」权限时截不到窗口，这是唯一能看到界面的验收手段。
enum RenderHarness {

    static func run(_ arguments: [String]) -> Int32 {
        let path = arguments.first(where: { $0.hasSuffix(".png") }) ?? "/tmp/chemcards.png"
        let scene = arguments.first(where: { !$0.hasPrefix("-") && !$0.hasSuffix(".png") }) ?? "menu"
        let size = NSSize(width: 1360, height: 860)

        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        let root: AnyView
        switch scene {
        case "table": root = AnyView(tableScene(size: size))
        case "rules": root = AnyView(GameRootView(scene: .rules))
        case "cards": root = AnyView(cardScene())
        case "banner": root = AnyView(bannerScene())
        case "log": root = AnyView(logScene())
        case "result": root = AnyView(resultScene())
        default: root = AnyView(GameRootView())
        }

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        // 让 SwiftUI 把已经发生的事件铺进视图树
        if scene == "table" || scene == "result" {
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            hosting.layoutSubtreeIfNeeded()
        }

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            FileHandle.standardError.write(Data("无法创建位图\n".utf8))
            return 1
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("无法编码 PNG\n".utf8))
            return 1
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("✓ \(scene) → \(path)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("写入失败：\(error)\n".utf8))
            return 1
        }
    }

    // MARK: 场景

    private static func tableScene(size: NSSize) -> some View {
        let director = StageDirector(players: MatchSetup.seats(human: .sanae, table: .mixed),
                                     seed: 0xC0FF_EE01)
        advance(director, hands: 7)
        // 停在 AI 回合时整排手牌都是压暗的「还没轮到你」，看不出默认给不给牌标色
        advanceUntilHumanTurn(director)
        return TableView(director: director, onExit: {}, onRestart: {})
            .frame(width: size.width, height: size.height)
    }

    /// 替 AI 走子，直到轮到 0 号位为止
    private static func advanceUntilHumanTurn(_ director: StageDirector, cap: Int = 40) {
        for _ in 0..<cap {
            let state = director.state
            if state.phase.isOver || state.isHumanTurn { return }
            guard let decision = state.aiDecision() else { return }
            state.apply(decision)
        }
    }

    /// 0 号位是人类，截图时替它出牌，其余交给导演的 AI 时钟
    private static func advance(_ director: StageDirector, hands: Int) {
        for _ in 0..<hands {
            if director.state.phase.isOver { break }
            if director.state.isHumanTurn {
                if let card = director.state.legalMoves().max(by: {
                    ($0.species?.tier == .senior ? 1 : 0) < ($1.species?.tier == .senior ? 1 : 0)
                }) {
                    director.play(card)
                } else {
                    director.draw()
                }
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.7))
        }
    }

    private static func cardScene() -> some View {
        let picks = ["hcl", "naoh", "cuso4", "fe", "cao", "co2", "c2h5oh", "agno3"]
            .compactMap { TestCatalog.species($0) }
        let cards = picks.enumerated().map { Card(species: $0.element, uid: $0.offset) }
        return ZStack {
            Theme.Color.windowBackground
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(cards) { card in
                    CardView(card: card, width: 120, look: card.uid == 0 ? .legal : .normal)
                }
                CardView(card: Card(action: .pump, uid: 99), width: 120, look: .illegal)
            }
            .padding(30)
        }
    }

    private static func bannerScene() -> some View {
        let event = TestCatalog.firstReactionEvent()
        return ZStack {
            Theme.Color.windowBackground
            if let event {
                ReactionBannerView(event: event, playerName: "雾雨魔理沙")
            } else {
                Text("找不到可用反应").foregroundStyle(.white)
            }
        }
    }

    private static func logScene() -> some View {
        let director = StageDirector(players: MatchSetup.seats(human: .sanae, table: .expert),
                                     seed: 0xC0FF_EE02)
        advance(director, hands: 14)
        return HStack(spacing: 0) {
            Theme.Color.windowBackground
            LogDrawerView(state: director.state, onClose: {})
        }
    }

    private static func resultScene() -> some View {
        let director = StageDirector(players: MatchSetup.allAI(difficulty: .expert),
                                     seed: 0xC0FF_EE03)
        let state = director.state
        var steps = 0
        while !state.phase.isOver && steps < MatchRules.standard.maxTurns {
            steps += 1
            guard let decision = state.aiDecision() else { break }
            state.apply(decision)
        }
        return ZStack {
            Theme.Color.windowBackground.opacity(0.9)
            ResultView(state: state, onRestart: {}, onExit: {})
        }
    }
}

/// 渲染场景用的最小素材工厂（测试与截图共用，不参与游戏逻辑）
enum TestCatalog {

    static func species(_ id: String) -> Species? {
        Chemistry.all.first { $0.id == id }
    }

    static func firstReactionEvent() -> GameState.PlayEvent? {
        guard let top = species("hcl"), let play = species("naoh"),
              let reaction = ReactionEngine.resolve(top, play) else { return nil }
        return GameState.PlayEvent(seat: 1,
                                   card: Card(species: play, uid: 500),
                                   reaction: reaction)
    }
}

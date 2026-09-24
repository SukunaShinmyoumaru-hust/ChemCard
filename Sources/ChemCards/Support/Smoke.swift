import Foundation

/// 自检开关：`--smoke-test` 启动时打印一行状态后退出，用来验证打包产物真的能起界面、资源真的读到了。
/// 打印本身在两端各自实现（macOS 在 `App/AppDelegate.swift`，iPhone 在 `Sources/ChemCardsiOS/App/`），
/// 但这行文字由 `report()` 统一产出，验证脚本只 grep 一种格式。
enum Smoke {

    static var enabled = CommandLine.arguments.contains("--smoke-test")

    static func report() -> String {
        // count 先算：它会触发 ensureLoaded，之后 describeSource 才有意义
        "reactions=\(ReactionTable.count) table=\(ReactionTable.describeSource) assets=\(assetProbe)"
    }

    /// 反应表、牌桌背景、立绘都可能静默降级（现场推导、渐变底色、程序化脸），
    /// 降级后的界面看着照样"正常"，所以必须显式报出来
    static var assetProbe: String {
        let table = AssetLoader.url("Table/table_bg.png") != nil ? "table:file" : "table:missing"
        let face = AssetLoader.url("Characters/\(CharacterID.reimu.folder)/base.png") != nil
            ? "portrait:file" : "portrait:missing"
        return "\(table),\(face)"
    }

    // MARK: 无头截图用的场景

    /// 截图脚本没法在屏幕上点，只能让 app 自己启动到某个界面
    static var scene: Scene {
        guard let raw = CommandLine.arguments.first(where: { $0.hasPrefix("--scene=") })?
            .dropFirst("--scene=".count) else { return .menu }
        return Scene(rawValue: String(raw)) ?? .menu
    }

    enum Scene: String { case menu, rules, table, banner, log, result }

    /// 把棋局推到要截的那一格。导演的 AI 时钟靠主轮询走，启动阶段还没转起来，
    /// 所以这里必须自己替 AI 落子，不能等它
    static func stage(_ director: StageDirector, for scene: Scene) {
        switch scene {
        case .menu, .rules:
            break
        case .table:
            break
        case .banner:
            advance(director, hands: 1)
        case .log:
            advance(director, hands: 12)
            director.showLog = true
        case .result:
            // 每手一个座位，跑到 phase 终了为止；回合上限保证不会无限循环
            advance(director, hands: 600)
        }
    }

    private static func advance(_ director: StageDirector, hands: Int) {
        let state = director.state
        for _ in 0..<hands {
            guard !state.phase.isOver else { return }
            if state.isHumanTurn {
                // 人类这一手替它出：优先能真正反应的牌，好让横幅有方程式可看
                if let card = state.legalMoves().max(by: { $0.action != nil && $1.action == nil }) {
                    director.play(card)
                } else {
                    director.draw()
                }
            } else if let decision = state.aiDecision() {
                state.apply(decision)
            } else {
                return
            }
        }
    }
}

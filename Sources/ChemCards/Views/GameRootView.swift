import SwiftUI

/// 根视图：主菜单 → 牌桌。重开靠换 `round` 让牌桌子视图整体重建，状态干净
struct GameRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var human: CharacterID = .sanae
    @State private var table: TableDifficulty = .mixed
    @State private var round = 0
    @State private var inGame = false
    @State private var showRules = false

    /// 默认从主菜单进；无头截图用 `--scene=` 直达某个界面，脚本没法替人点屏幕
    init(scene: Smoke.Scene = .menu) {
        _inGame = State(initialValue: scene != .menu && scene != .rules)
        _showRules = State(initialValue: scene == .rules)
        _scene = State(initialValue: scene)
    }

    @State private var scene: Smoke.Scene

    var body: some View {
        ZStack {
            if inGame {
                GameScreen(players: MatchSetup.seats(human: human, table: table),
                           seed: MatchRules.defaultSeed &+ UInt64(round &* 7_919),
                           scene: scene,
                           onExit: { inGame = false },
                           onRestart: { round += 1 })
                    .id(round)
                    .transition(.opacity)
            } else {
                menu
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: inGame)
    }

    // MARK: 主菜单

    private var menu: some View {
        // 背景必须走 .background 而不是 ZStack 兄弟节点：scaledToFill 会把
        // 自己放大后的尺寸（1112pt）报给 ZStack，ScrollView 于是按这个宽度排版，
        // 内容整片被推到屏幕外，标题跑到 x=-347 去了
        menuBody
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(menuBackdrop)
            .overlay {
                if showRules {
                    RulesCard(onClose: { showRules = false })
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showRules)
    }

    /// 手机屏矮，装不下就得滚；桌面保持原来的固定居中
    @ViewBuilder private var menuBody: some View {
        if SceneLayout.isPhone {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    menuStack.frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        } else {
            menuStack
        }
    }

    private var menuStack: some View {
        VStack(spacing: SceneLayout.menuSpacing) {
            menuHeader
            menuPanel
            menuActions
            Text(SceneLayout.menuHint)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.Color.textSecondary.opacity(0.8))
        }
        .padding(SceneLayout.menuPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var menuHeader: some View {
        VStack(spacing: 7) {
            Text("CHEMISTRY  POKER")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(4)
                .foregroundStyle(Theme.Color.accent.opacity(0.9))
            Text("化学扑克牌")
                .font(Theme.Font.title(SceneLayout.titleSize))
                .foregroundStyle(Theme.Color.textPrimary)
            Text("容器里是一槽混合物，接得住才打得出去 · HCl + NaOH → NaCl + H₂O")
                .font(.system(size: SceneLayout.subtitleSize, design: .rounded))
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: SceneLayout.subtitleWidth)
        }
    }

    private var menuPanel: some View {
        VStack(spacing: SceneLayout.panelSpacing) {
            MenuSection(title: "你的立绘", note: SceneLayout.portraitNote) {
                CharacterRow(selected: human, reduceMotion: reduceMotion) { human = $0 }
            }

            Divider().overlay(Theme.Color.panelStroke)

            MenuSection(title: "对手强度", note: SceneLayout.difficultyNote(table.summary)) {
                HStack(spacing: SceneLayout.difficultyChipSpacing) {
                    ForEach(TableDifficulty.allCases) { difficulty in
                        DifficultyChoice(difficulty: difficulty,
                                         selected: difficulty == table) {
                            table = difficulty
                        }
                    }
                }
            }
        }
        .padding(SceneLayout.panelPadding)
        .frame(maxWidth: SceneLayout.panelMaxWidth)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(SwiftUI.Color(white: 0.06).opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
        .overlay(alignment: .top) {
            Capsule()
                .fill(LinearGradient(colors: [Theme.Color.accent.opacity(0.55), SwiftUI.Color.clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .padding(.horizontal, 24)
                .padding(.top, 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 26, x: 0, y: 14)
    }

    @ViewBuilder private var menuActions: some View {
        if SceneLayout.isPhone {
            VStack(spacing: 10) {
                startButton
                rulesButton
            }
        } else {
            HStack(spacing: 14) {
                startButton
                rulesButton
            }
        }
    }

    private var startButton: some View {
        Button { inGame = true } label: {
            Text("开始反应")
                .fontWeight(.bold)
                .buttonSized(width: SceneLayout.startButtonWidth, height: SceneLayout.buttonHeight)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.Color.accent)
    }

    /// 手机上 .bordered + 16% 白底几乎看不见，得自己描一圈边、把字提亮
    @ViewBuilder private var rulesButton: some View {
        if SceneLayout.isPhone {
            Button { showRules.toggle() } label: {
                Text("玩法与规则")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: SceneLayout.buttonHeight)
            }
            .buttonStyle(.bordered)
            .tint(SwiftUI.Color.white.opacity(0.14))
            .foregroundStyle(Theme.Color.textPrimary)
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
        } else {
            Button { showRules.toggle() } label: {
                Text("玩法与规则")
                    .fontWeight(.semibold)
                    .frame(width: SceneLayout.rulesButtonWidth, height: SceneLayout.buttonHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(SwiftUI.Color.white.opacity(0.16))
        }
    }

    /// 牌桌背景优先，缺图退化成渐变；压暗一层标题和立绘才站得住
    private var menuBackdrop: some View {
        ZStack {
            if let image = AssetLoader.tableBackground() {
                image.resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Theme.Color.tableFelt, Theme.Color.windowBackground],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .overlay(SwiftUI.Color.black.opacity(0.52))
        .overlay(
            RadialGradient(colors: [Theme.Color.accent.opacity(0.12), SwiftUI.Color.clear],
                           center: .center, startRadius: 20, endRadius: 560)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// 一局游戏的容器：在这里创建导演，重开时整体重建
struct GameScreen: View {
    @StateObject private var director: StageDirector
    var onExit: () -> Void
    var onRestart: () -> Void

    init(players: [Player],
         seed: UInt64,
         scene: Smoke.Scene = .menu,
         onExit: @escaping () -> Void,
         onRestart: @escaping () -> Void) {
        let director = StageDirector(players: players, seed: seed)
        Smoke.stage(director, for: scene)
        _director = StateObject(wrappedValue: director)
        self.onExit = onExit
        self.onRestart = onRestart
    }

    @ViewBuilder var body: some View {
        if SceneLayout.isPhone {
            PhoneTableView(director: director, onExit: onExit, onRestart: onRestart)
        } else {
            TableView(director: director, onExit: onExit, onRestart: onRestart)
        }
    }
}

/// 菜单里的一段：左侧标题、右侧一行小字说明
struct MenuSection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if SceneLayout.isPhone {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Color.accent)
                    noteText
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Color.accent)
                    noteText
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            content
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var noteText: some View {
        Group {
            if let note {
                Text(note)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 立绘选择条：动画时钟只包住这一条，主菜单其余部分不必跟着每帧重算
struct CharacterRow: View {
    let selected: CharacterID
    var reduceMotion: Bool
    var onPick: (CharacterID) -> Void

    var body: some View {
        if reduceMotion {
            row(time: 0)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { timeline in
                row(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func row(time: Double) -> some View {
        // LazyVGrid 在这个 ScrollView 里整片渲染成空白，七个格子也用不着 lazy
        VStack(spacing: SceneLayout.characterSpacing) {
            ForEach(Array(characterRows.enumerated()), id: \.offset) { _, characters in
                HStack(spacing: SceneLayout.characterSpacing) {
                    ForEach(characters) { choice($0, time) }
                }
            }
        }
    }

    /// 一行只放得下 SceneLayout.characterColumns 个立绘，剩下的折到下一行
    private var characterRows: [[CharacterID]] {
        let all = CharacterID.allCases
        let columns = SceneLayout.characterColumns
        return stride(from: 0, to: all.count, by: columns)
            .map { Array(all[$0..<min($0 + columns, all.count)]) }
    }

    private func choice(_ character: CharacterID, _ time: Double) -> some View {
        CharacterChoice(character: character,
                        selected: character == selected,
                        time: time,
                        reduceMotion: reduceMotion,
                        portrait: SceneLayout.portraitSize) {
            onPick(character)
        }
    }
}

struct CharacterChoice: View {
    let character: CharacterID
    let selected: Bool
    var time: Double
    var reduceMotion: Bool
    var portrait: CGFloat
    var onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 12) {
                PortraitRig(character: character,
                            mood: selected ? .win : .idle,
                            size: portrait,
                            time: time,
                            reduceMotion: reduceMotion)
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.Color.legalGlow)
                                .padding(3)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(character.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                    // 选人的时候就得知道自己选到了什么技能，一局一次不能靠试
                    if let skill = character.skill {
                        Text(skill.displayName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Color.accent)
                    }
                }
                Spacer(minLength: 8)
                if let skill = character.skill {
                    Text(skill.hint)
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? Theme.Color.accent.opacity(0.14) : Theme.Color.panel))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Theme.Color.accent : Theme.Color.panelStroke, lineWidth: 1.4))
        }
        .buttonStyle(.plain)
    }
}

struct DifficultyChoice: View {
    let difficulty: TableDifficulty
    let selected: Bool
    var onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            VStack(spacing: 3) {
                Text(difficulty.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(difficulty.seats.map(\.shortName).joined(separator: "·"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .opacity(0.7)
            }
            .foregroundStyle(selected ? SwiftUI.Color(white: 0.08) : Theme.Color.textPrimary)
            .frame(width: SceneLayout.difficultyChipWidth, height: 46)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(selected ? Theme.Color.accent : Theme.Color.panel))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(selected ? Theme.Color.accent : Theme.Color.panelStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(difficulty.summary)
    }
}

/// 规则卡：把玩法一次讲清楚
struct RulesCard: View {
    var onClose: () -> Void

    private var sections: [(String, [String])] {
        [
            ("出牌", [
                "反应容器里是一槽混合物：最近倒进去的三种物质都还在，你打出的试剂牌必须能和其中至少一种真正发生化学反应，方程式由反应表裁定。",
                "接不上就摸一张，摸完这一手就交给下家。牌堆空了会把容器里用掉的旧牌洗回牌堆；连旧牌都不剩、手里又一张都接不上，这一手过牌。",
                "功能牌任何时候都能打，它们只是操作，不往容器里加物质。",
                SceneLayout.verdictLine
            ]),
            ("胜负", [
                "谁先出完手牌谁立刻赢，不看分数。",
                SceneLayout.callLine,
                "结算会点名本局最漂亮的一次反应：配平最复杂、现象最丰富的那一手。"
            ]),
            ("功能牌", [
                "注液泵 +2：下家摸两张并跳过回合。",
                "惰性气氛：下家跳过一回合。",
                "可逆反应：出牌方向反向。",
                "检液：偷看牌堆顶三张。"
            ]),
            ("角色技能", CharacterID.allCases.compactMap { character in
                character.skill.map { "\(character.displayName)「\($0.displayName)」：\($0.hint)。" }
            } + ["技能每局只能用一次，只有你手上这个角色有；AI 不用技能。"]),
            ("其它", [
                "AI 只能看到公开信息：自己的手牌、弃牌堆、各家手牌张数和牌堆剩余量。",
                SceneLayout.assetLine
            ])
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("怎么玩")
                    .font(Theme.Font.title(22))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: SceneLayout.isPhone ? 26 : 18))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(section.0)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Color.accent)
                            ForEach(Array(section.1.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("·").foregroundStyle(Theme.Color.textSecondary)
                                    Text(line)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(Theme.Color.textPrimary.opacity(0.92))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(22)
        .padding(.bottom, SceneLayout.rulesExtraBottom)
        .frame(width: SceneLayout.rulesSize?.width, height: SceneLayout.rulesSize?.height)
        .background(RoundedRectangle(cornerRadius: SceneLayout.rulesCorner, style: .continuous)
            .fill(SwiftUI.Color(white: 0.09)))
        .overlay(RoundedRectangle(cornerRadius: SceneLayout.rulesCorner, style: .continuous)
            .strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 16)
    }
}

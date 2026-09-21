import SwiftUI

/// 根视图：主菜单 → 牌桌。重开靠换 `round` 让牌桌子视图整体重建，状态干净
struct GameRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var human: CharacterID = .reimu
    @State private var table: TableDifficulty = .mixed
    @State private var round = 0
    @State private var inGame = false
    @State private var showRules = false

    var body: some View {
        ZStack {
            if inGame {
                GameScreen(players: MatchSetup.seats(human: human, table: table),
                           seed: MatchRules.defaultSeed &+ UInt64(round &* 7_919),
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
        ZStack {
            menuBackdrop

            VStack(spacing: 20) {
                VStack(spacing: 7) {
                    Text("CHEMISTRY  POKER")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .kerning(4)
                        .foregroundStyle(Theme.Color.accent.opacity(0.9))
                    Text("化学扑克牌")
                        .font(Theme.Font.title(46))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("容器里是一槽混合物，接得住才打得出去 · HCl + NaOH → NaCl + H₂O")
                        .font(.system(size: 13.5, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                VStack(spacing: 16) {
                    MenuSection(title: "你的立绘", note: "换图不用重新编译，覆盖 assets/Characters/<角色>/base.png 即可") {
                        CharacterRow(selected: human, reduceMotion: reduceMotion) { human = $0 }
                    }

                    Divider().overlay(Theme.Color.panelStroke)

                    MenuSection(title: "对手强度", note: table.summary) {
                        HStack(spacing: 10) {
                            ForEach(TableDifficulty.allCases) { difficulty in
                                DifficultyChoice(difficulty: difficulty,
                                                 selected: difficulty == table) {
                                    table = difficulty
                                }
                            }
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: 780)
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

                HStack(spacing: 14) {
                    Button { inGame = true } label: {
                        Text("开始反应")
                            .fontWeight(.bold)
                            .frame(width: 180, height: 40)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.Color.accent)

                    Button { showRules.toggle() } label: {
                        Text("玩法与规则")
                            .fontWeight(.semibold)
                            .frame(width: 140, height: 40)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(SwiftUI.Color.white.opacity(0.16))
                }

                Text("提示：接不上就摸牌；灰掉的牌长按或右键，能看出它为什么不反应。")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary.opacity(0.8))
            }
            .padding(34)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if showRules {
                RulesCard(onClose: { showRules = false })
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showRules)
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

    init(players: [Player], seed: UInt64, onExit: @escaping () -> Void, onRestart: @escaping () -> Void) {
        _director = StateObject(wrappedValue: StageDirector(players: players, seed: seed))
        self.onExit = onExit
        self.onRestart = onRestart
    }

    var body: some View {
        TableView(director: director, onExit: onExit, onRestart: onRestart)
    }
}

/// 菜单里的一段：左侧标题、右侧一行小字说明
private struct MenuSection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.accent)
                if let note {
                    Text(note)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            content
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// 立绘选择条：动画时钟只包住这一条，主菜单其余部分不必跟着每帧重算
private struct CharacterRow: View {
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
        HStack(spacing: 18) {
            ForEach(CharacterID.allCases) { character in
                CharacterChoice(character: character,
                                selected: character == selected,
                                time: time,
                                reduceMotion: reduceMotion) {
                    onPick(character)
                }
            }
        }
    }
}

private struct CharacterChoice: View {
    let character: CharacterID
    let selected: Bool
    var time: Double
    var reduceMotion: Bool
    var onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            VStack(spacing: 8) {
                PortraitRig(character: character,
                            mood: selected ? .win : .idle,
                            size: 118,
                            time: time,
                            reduceMotion: reduceMotion)
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.Color.legalGlow)
                                .padding(5)
                        }
                    }
                Text(character.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(selected ? Theme.Color.textPrimary : Theme.Color.textSecondary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selected ? Theme.Color.accent.opacity(0.14) : Theme.Color.panel))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(selected ? Theme.Color.accent : Theme.Color.panelStroke, lineWidth: 1.4))
        }
        .buttonStyle(.plain)
    }
}

private struct DifficultyChoice: View {
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
            .frame(width: 108, height: 46)
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
private struct RulesCard: View {
    var onClose: () -> Void

    private let sections: [(String, [String])] = [
        ("出牌", [
            "反应容器里是一槽混合物：最近倒进去的三种物质都还在，你打出的试剂牌必须能和其中至少一种真正发生化学反应，方程式由反应表裁定。",
            "接不上就摸一张，摸完这一手就交给下家。牌堆空了会把容器里用掉的旧牌洗回牌堆；连旧牌都不剩、手里又一张都接不上，这一手过牌。",
            "功能牌任何时候都能打，它们只是操作，不往容器里加物质。",
            "灰掉的牌长按 0.45 秒或右键「检视这张牌」，会写明它为什么接不上。"
        ]),
        ("胜负", [
            "谁先出完手牌谁立刻赢，不看分数。",
            "手里只剩一张时必须先喊「反应!」（空格）再出牌，忘了罚抽一张。",
            "结算会点名本局最漂亮的一次反应：配平最复杂、现象最丰富的那一手。"
        ]),
        ("功能牌", [
            "注液泵 +2：下家摸两张并跳过回合。",
            "惰性气氛：下家跳过一回合。",
            "可逆反应：出牌方向反向。",
            "检液：偷看牌堆顶三张。"
        ]),
        ("其它", [
            "AI 只能看到公开信息：自己的手牌、弃牌堆、各家手牌张数和牌堆剩余量。",
            "牌桌立绘和背景可以替换：把图片放进 ~/Library/Application Support/ChemCards/assets/Characters/<角色>/ 即可，不用重新编译。"
        ])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("怎么玩")
                    .font(Theme.Font.title(22))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
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
        .frame(width: 560, height: 520)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SwiftUI.Color(white: 0.09)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 16)
    }
}

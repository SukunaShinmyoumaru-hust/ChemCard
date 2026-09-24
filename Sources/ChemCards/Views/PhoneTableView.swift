import SwiftUI

/// 手机牌桌：从上到下六条带，全部用栈排。
/// 桌面那张靠 `.position` 按横屏画布的比例摆位，竖屏一压四个座位就叠成一坨；
/// 分带能自己吃下 SE3 → 14 Pro Max 的高度差，也能吃下 7 → 20 张手牌。
struct PhoneTableView: View {
    @ObservedObject var director: StageDirector
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onExit: () -> Void
    var onRestart: () -> Void

    private var state: GameState { director.state }

    @State private var sortMode: TableView.HandSort = .category
    @State private var selectedUID: Int?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            VStack(spacing: SceneLayout.bandSpacing) {
                PhoneToolBar(director: director,
                             sortMode: $sortMode,
                             onExit: onExit,
                             onRestart: onRestart)
                    .frame(height: SceneLayout.toolbarHeight)

                opponents
                statusLine.frame(height: SceneLayout.statusHeight)

                // 剩下的余量全给横幅：这游戏的爽点就是那一发方程式，不能挤。
                // zIndex 要抬高：VStack 里容器带画在它后面，自己的立绘会盖掉横幅左下角的现象标签
                bannerArea.zIndex(1)

                vessel
                bottomShelf(size: size)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            .frame(width: size.width, height: size.height)
            .background(backdrop)
            .overlay(presentation(size: size))
        }
        .background(Theme.Color.windowBackground)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: director.showLog)
        // 交牌之后上一张的选中态没有意义，留着还会让确认条显示一张打不出去的手牌
        .onChange(of: state.turn) { _ in selectedUID = nil }
    }

    // MARK: 背景

    /// 和主菜单同一个坑：`scaledToFill` 会把放大后的尺寸报给父层，只能挂在 .background 上
    private var backdrop: some View {
        ZStack {
            if let image = AssetLoader.tableBackground() {
                image.resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Theme.Color.tableFelt, Theme.Color.windowBackground],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .overlay(SwiftUI.Color.black.opacity(0.30))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    // MARK: 对手

    /// 台词不挂在立绘旁边：三个座位挤在一行，气泡会互相盖住，统一念到下面的状态行
    private var opponents: some View {
        HStack(alignment: .top, spacing: SceneLayout.seatSpacing) {
            ForEach(state.players.filter { !$0.isHuman }, id: \.seat) { player in
                SeatView(state: state,
                         seat: player.seat,
                         speech: nil,
                         mood: director.moods[player.seat] ?? .idle,
                         portraitSize: SceneLayout.seatPortrait,
                         reduceMotion: reduceMotion)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 状态行

    /// 固定高度：有台词时念台词，没台词时报「轮到谁」，切换不能让下面的带跳位。
    /// 方向和牌堆数容器那条带已经显示了，这里不重复占位
    private var statusLine: some View {
        HStack(spacing: 6) {
            // 横幅亮起时它自己就写了「谁打了什么」，这行再念一遍只会从横幅边上漏出半句
            if director.banner == nil {
                if let line = currentSpeech {
                    Text(line)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Chip(text: "轮到 \(state.currentPlayer.name)",
                         tint: state.isHumanTurn ? Theme.Color.legalGlow : Theme.Color.accent)
                }
            }
            Spacer(minLength: 4)
            skillButton
        }
    }

    /// 技能一局一次，摆状态行右端：操作行本来就被出牌/摸牌/喊反应占满，挤不下第四颗
    @ViewBuilder private var skillButton: some View {
        if state.isHumanTurn, let skill = state.currentPlayer.character.skill {
            Button { director.useSkill() } label: {
                Label(skill.shortName, systemImage: skill.symbol)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!director.canUseSkill)
            .help(skill.hint)
            .fixedSize()
        }
    }

    private var currentSpeech: String? {
        if let text = director.speech[state.turn] {
            return "\(state.currentPlayer.name)：\(text)"
        }
        for seat in director.speech.keys.sorted() {
            if let text = director.speech[seat] { return "\(state.players[seat].name)：\(text)" }
        }
        return nil
    }

    // MARK: 容器

    /// 自己的立绘挨着容器放：桌面上「你」就在牌桌下沿偏左、容器旁边，竖屏沿用这个相对位置
    private var vessel: some View {
        HStack(alignment: .bottom, spacing: SceneLayout.seatSpacing) {
            SeatView(state: state,
                     seat: 0,
                     speech: nil,
                     mood: director.moods[0] ?? .idle,
                     portraitSize: SceneLayout.seatPortrait,
                     reduceMotion: reduceMotion)

            VesselPileView(state: state,
                           cardWidth: SceneLayout.vesselCardWidth,
                           labelSize: 11,
                           compactCaption: true,
                           drawEnabled: director.canDrawCard,
                           onDraw: { director.draw() })
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: 手牌 + 确认条

    /// 手牌和确认条共用一个底：牌浮在桌布上很难读，压暗一层才站得住
    private func bottomShelf(size: CGSize) -> some View {
        VStack(spacing: 2) {
            hand(size: size)
            actions
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(LinearGradient(colors: [SwiftUI.Color.white.opacity(0.05),
                                          SwiftUI.Color.black.opacity(0.42)],
                                 startPoint: .top, endPoint: .bottom)))
    }

    private func hand(size: CGSize) -> some View {
        let cards = sortMode.apply(state.players[0].hand)
        let verdicts = Dictionary(uniqueKeysWithValues: cards.map { ($0.uid, state.playability(of: $0)) })
        let layout = SceneLayout.handLayout(count: cards.count,
                                            available: size.width - SceneLayout.handPadding)
        return PhoneHandBar(cards: cards,
                            verdicts: verdicts,
                            cardWidth: layout.cardWidth,
                            step: layout.step,
                            enabled: state.phase == .playing && state.isHumanTurn,
                            reduceMotion: reduceMotion,
                            reveal: state.hintArmed,
                            selected: selectedIndex(cards),
                            onPlay: { tap($0) })
    }

    private func selectedIndex(_ cards: [Card]) -> Int? {
        guard let uid = selectedUID else { return nil }
        return cards.firstIndex { $0.uid == uid }
    }

    private var selectedCard: Card? {
        guard let uid = selectedUID else { return nil }
        return state.players[0].hand.first { $0.uid == uid }
    }

    /// 点选而不是直接出牌：叠牌时相邻两张只差 20pt，点即出会打错而且收不回来
    private func tap(_ card: Card) {
        guard state.phase == .playing, state.isHumanTurn else {
            director.play(card)     // 让导演说清是谁还在出牌，不然像卡死
            return
        }
        selectedUID = selectedUID == card.uid ? nil : card.uid
    }

    private func confirmPlay() {
        guard let card = selectedCard else { return }
        selectedUID = nil
        director.play(card)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if let card = selectedCard {
                verdictBlock(card)
            } else {
                Text(containerLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if state.needsReactionCall {
                Button { director.callReaction() } label: {
                    Text("喊「反应!」").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.legalGlow)
                .foregroundStyle(SwiftUI.Color(white: 0.10))
                .fixedSize()
            }

            if let card = selectedCard {
                Button(action: confirmPlay) {
                    Text("出牌").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.playability(of: card).isIllegal
                        ? SwiftUI.Color(white: 0.28) : Theme.Color.accent)
                .foregroundStyle(SwiftUI.Color(white: 0.08))
                .disabled(state.playability(of: card).isIllegal)
                .frame(width: 76)
            } else if director.canPassTurn {
                Button { director.pass() } label: { Text("过牌").frame(maxWidth: .infinity) }
                    .frame(width: 76)
            } else {
                Button { director.draw() } label: { Text("摸牌").frame(maxWidth: .infinity) }
                    .disabled(!director.canDrawCard)
                    .frame(width: 76)
            }
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .frame(height: SceneLayout.actionHeight)
    }

    /// 选中那张牌的裁定：牌名 + 化学式 + 为什么打得出去或打不出去
    private func verdictBlock(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                Text(card.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(card.formulaLine)
                    .font(Theme.Font.formula(13))
                    .foregroundStyle(Theme.Color.accent)
            }
            .foregroundStyle(Theme.Color.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(verdictSummary(card))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(verdictTint(card))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verdictSummary(_ card: Card) -> String {
        switch state.playability(of: card) {
        case .reacts(let reaction): return "接得上 · \(reaction.displayEquation)"
        case .action(let action): return "\(action.displayName)：任何时候都能打"
        case .illegal(let reason): return reason
        }
    }

    private func verdictTint(_ card: Card) -> SwiftUI.Color {
        switch state.playability(of: card) {
        case .reacts: return Theme.Color.legalGlow
        case .action: return Theme.Color.accent
        case .illegal: return Theme.Color.danger
        }
    }

    /// 容器里那几种物质：手机上放不下三个 chip，压成一行会截断的文字
    private var containerLine: String {
        let names = state.vesselCards.reversed().map(\.title)
        return names.isEmpty ? "容器是空的" : "容器里：\(names.joined(separator: "、"))"
    }

    // MARK: 演出层

    /// 横幅不占固定带：它浮在余量里，SE3 上余量不够时可以压到邻居上面，反正两三秒就走。
    /// 这一片同时是「点空白处取消选中」的落点
    private var bannerArea: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { selectedUID = nil }
            .overlay {
                if let event = director.banner {
                    bannerView(event).allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                if let hint = director.hint {
                    ReasonBubble(text: hint.text)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8),
                       value: director.banner)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: director.hint)
    }

    @ViewBuilder private func bannerView(_ event: GameState.PlayEvent) -> some View {
        if let action = event.card.action {
            ActionNoticeView(action: action, playerName: state.players[event.seat].name)
        } else {
            ReactionBannerView(event: event,
                               playerName: state.players[event.seat].name,
                               reduceMotion: reduceMotion,
                               compact: true)
                .padding(.horizontal, 4)
        }
    }

    private func presentation(size: CGSize) -> some View {
        ZStack {
            if director.showLog {
                HStack(spacing: 0) {
                    Spacer()
                    LogDrawerView(state: state,
                                  panelWidth: size.width,
                                  onClose: { director.showLog = false })
                        .transition(.move(edge: .trailing))
                }
            }

            if state.phase.isOver {
                SwiftUI.Color.black.opacity(0.55).ignoresSafeArea()
                ResultView(state: state,
                           reduceMotion: reduceMotion,
                           width: SceneLayout.panelWidth(size.width, desktop: 560),
                           onRestart: onRestart,
                           onExit: onExit)
            }
        }
    }
}

/// 手机工具条：桌面的手册/重开/主菜单在 NSMenu 里，iOS 没有那东西，只能自己带
private struct PhoneToolBar: View {
    @ObservedObject var director: StageDirector
    @Binding var sortMode: TableView.HandSort
    var onExit: () -> Void
    var onRestart: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("出牌节奏", selection: $director.pace) {
                ForEach(StageDirector.PlayPace.allCases) { pace in
                    Text(pace.label).tag(pace)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 92)
            .labelsHidden()

            Picker("手牌排序", selection: $sortMode) {
                ForEach(TableView.HandSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 104)
            .labelsHidden()

            Spacer(minLength: 4)

            Button { director.showLog.toggle() } label: {
                Label("手册", systemImage: "book.closed")
            }
            Button(action: onRestart) {
                Label("重开", systemImage: "arrow.counterclockwise")
            }
            Button(action: onExit) {
                Label("主菜单", systemImage: "house")
            }
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
    }
}

import SwiftUI

/// 牌桌：背景 + 四个座位 + 中央反应容器 + 手牌 + 演出层
struct TableView: View {
    @ObservedObject var director: StageDirector
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onExit: () -> Void
    var onRestart: () -> Void

    private var state: GameState { director.state }

    @State private var inspected: Card?
    @State private var sortMode: HandSort = .category

    enum HandSort: String, CaseIterable {
        case category = "按类别"
        case activity = "按活性"
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                background(size: size)

                ForEach(state.players) { player in
                    seatView(player.seat, size: size)
                }

                vessel(size: size)
                humanArea(size: size)
                controls(size: size)
                presentation(size: size)
            }
            .frame(width: size.width, height: size.height)
        }
        .background(Theme.Color.windowBackground)
    }

    // MARK: 背景

    private func background(size: CGSize) -> some View {
        ZStack {
            if let image = AssetLoader.tableBackground() {
                image.resizable().scaledToFill()
            } else {
                RadialGradient(colors: [Theme.Color.tableFelt,
                                        SwiftUI.Color(red: 0.03, green: 0.06, blue: 0.09)],
                               center: .center,
                               startRadius: 40,
                               endRadius: max(size.width, size.height) * 0.78)
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(SwiftUI.Color.black.opacity(0.18))
    }

    // MARK: 座位

    private func seatView(_ seat: Int, size: CGSize) -> some View {
        let anchor = seatAnchor(seat)
        let portrait = seat == 0 ? size.height * 0.20 : size.height * 0.15
        let half = portrait * 1.3
        let x = min(max(half, anchor.x * size.width), size.width - half)
        return SeatView(state: state,
                        seat: seat,
                        speech: director.speech[seat],
                        mood: director.moods[seat] ?? .idle,
                        portraitSize: portrait,
                        reduceMotion: reduceMotion)
            .frame(width: portrait * 2.6)
            .position(x: x, y: anchor.y * size.height)
    }

    /// 0 号位在下方偏左，其余按顺时针排到左上、正上、右上
    private func seatAnchor(_ seat: Int) -> CGPoint {
        switch seat % 4 {
        case 0: return CGPoint(x: 0.145, y: 0.775)
        case 1: return CGPoint(x: 0.075, y: 0.30)
        case 2: return CGPoint(x: 0.5, y: 0.165)
        default: return CGPoint(x: 0.925, y: 0.30)
        }
    }

    // MARK: 容器

    private func vessel(size: CGSize) -> some View {
        VesselPileView(state: state,
                       cardWidth: size.width * 0.056,
                       drawEnabled: director.canDrawCard,
                       onDraw: { director.draw() })
            .position(x: size.width * 0.5, y: size.height * 0.52)
    }

    // MARK: 人类区域

    private func humanArea(size: CGSize) -> some View {
        let cardWidth = min(size.width * 0.070, size.height * 0.150)
        let hand = sorted(state.players[0].hand)
        let verdicts = Dictionary(uniqueKeysWithValues: hand.map { ($0.uid, state.playability(of: $0)) })
        return VStack(spacing: 6) {
            HandView(cards: hand,
                     verdicts: verdicts,
                     cardWidth: cardWidth,
                     enabled: state.phase == .playing && state.isHumanTurn,
                     reduceMotion: reduceMotion,
                     onPlay: { director.play($0) },
                     onInspect: { inspected = $0 })

            ActionBar(director: director, cardWidth: cardWidth)
        }
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .background(alignment: .bottom) {
            handShelf(width: size.width * 0.985,
                      height: cardWidth / Theme.cardAspect + cardWidth * 1.05)
        }
        .offset(y: -10)
    }

    /// 手牌底下垫一条台沿：牌浮在背景图上时很难读，压暗一层就站得住
    private func handShelf(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [SwiftUI.Color.white.opacity(0.05),
                                              SwiftUI.Color.black.opacity(0.42)],
                                     startPoint: .top, endPoint: .bottom))
            Capsule()
                .fill(LinearGradient(colors: [SwiftUI.Color.clear,
                                              Theme.Color.accent.opacity(0.30),
                                              SwiftUI.Color.clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
                .padding(.horizontal, width * 0.12)
        }
        .frame(width: width, height: height)
    }

    private func sorted(_ cards: [Card]) -> [Card] {
        switch sortMode {
        case .category:
            return cards.sorted {
                let a = CardCategory.allCases.firstIndex(of: $0.category) ?? 0
                let b = CardCategory.allCases.firstIndex(of: $1.category) ?? 0
                return a != b ? a < b : $0.title < $1.title
            }
        case .activity:
            return cards.sorted { $0.activityScale != $1.activityScale
                ? $0.activityScale > $1.activityScale : $0.title < $1.title }
        }
    }

    // MARK: 控制

    private func controls(size: CGSize) -> some View {
        VStack(spacing: 0) {
            StatusBar(director: director, sortMode: $sortMode, onExit: onExit, onRestart: onRestart)
                .frame(height: 42)
                .padding(.horizontal, 14)
            Spacer()
            if state.needsReactionCall {
                ReactionCallButton { director.callReaction() }
                    .padding(.bottom, size.height * 0.28)
            }
        }
    }

    // MARK: 演出层

    private func presentation(size: CGSize) -> some View {
        ZStack {
            if let event = director.banner {
                Group {
                    if let action = event.card.action {
                        ActionNoticeView(action: action, playerName: state.players[event.seat].name)
                    } else {
                        ReactionBannerView(event: event,
                                           playerName: state.players[event.seat].name,
                                           reduceMotion: reduceMotion)
                    }
                }
                .position(x: size.width * 0.5, y: size.height * 0.265)
                .allowsHitTesting(false)
            }

            if let hint = director.hint {
                ReasonBubble(text: hint.text)
                    .position(x: size.width * 0.5, y: size.height * 0.635)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }

            if let card = inspected {
                SwiftUI.Color.black.opacity(0.35)
                    .onTapGesture { inspected = nil }
                CardInspector(card: card,
                              verdict: state.playability(of: card, forSeat: 0),
                              contents: state.contents,
                              onClose: { inspected = nil })
                    .position(x: size.width * 0.5, y: size.height * 0.44)
            }

            if director.showLog {
                HStack(spacing: 0) {
                    Spacer()
                    LogDrawerView(state: state, onClose: { director.showLog = false })
                        .transition(.move(edge: .trailing))
                }
            }

            if state.phase.isOver {
                SwiftUI.Color.black.opacity(0.55)
                ResultView(state: state,
                           reduceMotion: reduceMotion,
                           onRestart: onRestart,
                           onExit: onExit)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: director.banner)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: director.hint)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: director.showLog)
    }
}

/// 手牌下方的一排操作：摸牌、喊反应提示、当前回合说明
private struct ActionBar: View {
    @ObservedObject var director: StageDirector
    var cardWidth: CGFloat

    private var state: GameState { director.state }

    var body: some View {
        HStack(spacing: 10) {
            if !state.vesselCards.isEmpty {
                HStack(spacing: 5) {
                    Text("容器里")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                    ForEach(state.vesselCards.reversed()) { card in
                        ContentsChip(card: card)
                    }
                }
            }

            Spacer(minLength: 8)

            if !state.isHumanTurn && !state.phase.isOver {
                Text("\(state.currentPlayer.name) 正在出牌…")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            if director.canPassTurn {
                Button { director.pass() } label: {
                    Label("过牌", systemImage: "arrow.right.circle")
                }
                .keyboardShortcut("p", modifiers: [])
                .help("牌堆空了，这一手只能过")
            } else {
                if state.isHumanTurn && state.legalMoves().isEmpty && state.canDraw {
                    Text("一张都接不上，摸一张试试")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(SwiftUI.Color(red: 0.98, green: 0.78, blue: 0.42))
                }

                Button { director.draw() } label: {
                    Label("摸牌", systemImage: "square.stack.3d.up")
                }
                .disabled(!director.canDrawCard)
                .keyboardShortcut("d", modifiers: [])
            }

            if state.needsReactionCall {
                Text("只剩一张牌，先喊「反应!」再出牌（空格）")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Color.legalGlow)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .controlSize(.small)
        .padding(.horizontal, cardWidth * 0.4)
        .frame(maxWidth: 760)
    }
}

/// 顶部状态条
private struct StatusBar: View {
    @ObservedObject var director: StageDirector
    @Binding var sortMode: TableView.HandSort
    var onExit: () -> Void
    var onRestart: () -> Void

    private var state: GameState { director.state }

    var body: some View {
        HStack(spacing: 12) {
            Label("化学扑克牌", systemImage: "testtube.2")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Color.accent)

            Chip(text: "轮到 \(state.currentPlayer.name)")
            Chip(text: state.directionText)
            Chip(text: "牌堆 \(state.stock.count)")

            Spacer()

            Picker("出牌节奏", selection: $director.pace) {
                ForEach(StageDirector.PlayPace.allCases) { pace in
                    Text(pace.label).tag(pace)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 96)
            .labelsHidden()
            .help("AI 每一手的停留时间：读不完方程式就调慢")

            Picker("手牌排序", selection: $sortMode) {
                ForEach(TableView.HandSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(width: 92)
            .labelsHidden()

            Button { director.showLog.toggle() } label: {
                Label("手册", systemImage: "book.closed")
            }
            .keyboardShortcut("l", modifiers: .command)

            Button(action: onRestart) {
                Label("重开", systemImage: "arrow.counterclockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button(action: onExit) {
                Label("主菜单", systemImage: "house")
            }
        }
        .controlSize(.small)
    }
}

/// 「反应!」大按钮：手里只剩一张时出现
private struct ReactionCallButton: View {
    var action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill")
                Text("喊「反应!」")
            }
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(SwiftUI.Color(white: 0.10))
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(Capsule().fill(Theme.Color.legalGlow))
            .shadow(color: Theme.Color.legalGlow.opacity(pulse ? 0.85 : 0.35), radius: pulse ? 26 : 12)
            .scaleEffect(pulse ? 1.05 : 0.98)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(" ", modifiers: [])
        .help("手里只剩一张牌时必须喊，否则出完最后一张要罚抽")
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true } }
        .onDisappear { pulse = false }
    }
}

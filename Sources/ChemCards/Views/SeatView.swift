import SwiftUI

/// 对手座位：立绘 + 名牌 + 手牌背 + 台词气泡
struct SeatView: View {
    @ObservedObject var state: GameState
    let seat: Int
    var speech: String?
    var mood: RigMood
    var portraitSize: CGFloat
    var reduceMotion = false

    private var player: Player { state.players[seat] }
    private var isTurn: Bool { state.turn == seat && !state.phase.isOver }

    var body: some View {
        VStack(spacing: portraitSize * 0.06) {
            ZStack(alignment: .top) {
                AnimatedPortrait(character: player.character,
                                 mood: mood,
                                 talking: speech != nil,
                                 size: portraitSize,
                                 ringed: isTurn,
                                 reduceMotion: reduceMotion)

                if let speech {
                    SpeechBubble(text: speech, maxWidth: portraitSize * 2.1)
                        .offset(y: -portraitSize * 0.44)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }

            namePlate
            handBacks
        }
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.72), value: speech)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: mood)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.name)，手牌\(player.handCount)张\(isTurn ? "，正在出牌" : "")")
    }

    private var namePlate: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Text(player.name)
                    .font(.system(size: portraitSize * 0.16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(Theme.Color.textPrimary)
                if let difficulty = player.difficulty {
                    Text(difficulty.displayName.replacingOccurrences(of: " AI", with: ""))
                        .font(.system(size: portraitSize * 0.11, weight: .semibold, design: .rounded))
                        .foregroundStyle(difficultyTint)
                }
            }
            HStack(spacing: 6) {
                Text(player.handCount == 0 ? "出完" : "剩 \(player.handCount) 张")
                    .font(.system(size: portraitSize * 0.13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Color.accent)
                if player.calledReaction {
                    Text("已喊反应")
                        .font(.system(size: portraitSize * 0.10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Color.legalGlow)
                }
            }
        }
        .padding(.horizontal, portraitSize * 0.12)
        .padding(.vertical, portraitSize * 0.05)
        .background(Capsule().fill(SwiftUI.Color.black.opacity(isTurn ? 0.5 : 0.3)))
    }

    private var difficultyTint: SwiftUI.Color {
        switch player.difficulty {
        case .novice: return Theme.Color.accent
        case .intermediate: return SwiftUI.Color(red: 0.55, green: 0.78, blue: 1.0)
        case .expert: return SwiftUI.Color(red: 1.0, green: 0.62, blue: 0.42)
        case .none: return Theme.Color.textSecondary
        }
    }

    private var handBacks: some View {
        let shown = min(player.handCount, 8)
        let width = portraitSize * 0.20
        return ZStack {
            ForEach(0..<max(1, shown), id: \.self) { index in
                CardBackView(width: width, compact: true)
                    .offset(x: CGFloat(index) * width * 0.42 - CGFloat(max(0, shown - 1)) * width * 0.21)
            }
            if player.handCount > 8 {
                Text("+\(player.handCount - 8)")
                    .font(.system(size: width * 0.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(x: CGFloat(shown) * width * 0.42)
            }
        }
        .frame(height: width / Theme.cardAspect)
        .opacity(player.isHuman ? 0 : 1)
    }
}

/// 只有这一块按帧重画，避免动画时钟把整张牌桌拖着走
private struct AnimatedPortrait: View {
    let character: CharacterID
    let mood: RigMood
    let talking: Bool
    let size: CGFloat
    let ringed: Bool
    var reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            PortraitRig(character: character, mood: .idle, size: size, time: 0, reduceMotion: true)
                .overlay(ring(at: 0))
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                PortraitRig(character: character,
                            mood: mood,
                            talking: talking,
                            size: size,
                            time: time,
                            reduceMotion: false)
                    .overlay(ring(at: time))
            }
        }
    }

    /// 回合光环：两层描边冒充辉光，比每帧 shadow 便宜得多
    @ViewBuilder
    private func ring(at time: Double) -> some View {
        if ringed {
            let dash: [CGFloat] = reduceMotion ? [] : [7, 5]
            let phase = reduceMotion ? CGFloat(0) : CGFloat(time.truncatingRemainder(dividingBy: 2.4)) * 12
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .strokeBorder(Theme.Color.legalGlow.opacity(0.22), lineWidth: size * 0.10)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .strokeBorder(Theme.Color.legalGlow,
                                      style: StrokeStyle(lineWidth: 2.4, dash: dash, dashPhase: phase))
                )
        }
    }
}

/// 立绘旁的台词气泡
struct SpeechBubble: View {
    let text: String
    var maxWidth: CGFloat = 240

    /// 气泡贴合台词长度：CJK 约一字一字号宽，超出上限才换行
    private var bubbleWidth: CGFloat {
        let glyphs = text.reduce(CGFloat(0)) { $0 + ($1.isASCII ? 7.2 : 13.2) }
        return min(maxWidth, max(72, glyphs) + 24)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(SwiftUI.Color(white: 0.13))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: bubbleWidth)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(SwiftUI.Color.white.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(SwiftUI.Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 7, x: 0, y: 3)
    }
}

/// 非法出牌的教学气泡：告诉玩家为什么这张牌放不下去
struct ReasonBubble: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("为什么不反应", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Color.danger)
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 380, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SwiftUI.Color.black.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Theme.Color.danger.opacity(0.55), lineWidth: 1))
    }
}

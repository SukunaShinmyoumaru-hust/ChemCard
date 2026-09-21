import SwiftUI

/// 结算面板：名次、反应分、MVP 反应
struct ResultView: View {
    @ObservedObject var state: GameState
    var reduceMotion = false
    var onRestart: () -> Void
    var onExit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            header

            VStack(spacing: 8) {
                ForEach(state.standings()) { standing in
                    StandingRow(standing: standing,
                                player: state.players[standing.seat],
                                time: 0,
                                highlight: standing.rank == 1)
                }
            }

            if let best = state.best {
                VStack(alignment: .leading, spacing: 6) {
                    Label("本局最漂亮的一次反应", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Color.accent)
                    Text(best.reaction.displayEquation)
                        .font(Theme.Font.formula(19))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text("\(best.reaction.rule) · \(state.players[best.seat].name) 打出 · \(best.reaction.phenomenonText)")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                    if let note = best.reaction.note {
                        Text("易错点：\(note)")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(SwiftUI.Color(red: 0.98, green: 0.78, blue: 0.42))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.Color.panel))
            }

            HStack(spacing: 12) {
                Button(action: onRestart) {
                    Text("再来一局")
                        .frame(width: 140)
                }
                .keyboardShortcut(.defaultAction)
                Button(action: onExit) {
                    Text("回主菜单")
                        .frame(width: 140)
                }
            }
            .controlSize(.large)
        }
        .padding(26)
        .frame(width: 560)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(SwiftUI.Color(white: 0.09).opacity(0.97)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.65), radius: 40, x: 0, y: 20)
        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
    }

    private var header: some View {
        VStack(spacing: 6) {
            switch state.phase {
            case .playing:
                EmptyView()
            case .finished(let winner):
                Text(state.players[winner].isHuman ? "你赢了！" : "\(state.players[winner].name) 获胜")
                    .font(Theme.Font.title(30))
                    .foregroundStyle(Theme.Color.legalGlow)
                Text("最先出完手牌")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            case .stalled(let turns):
                Text("回合用尽，按剩牌数结算")
                    .font(Theme.Font.title(26))
                    .foregroundStyle(SwiftUI.Color(red: 0.98, green: 0.78, blue: 0.42))
                Text("打了 \(turns) 手都没出完，翻看一下手册再来。")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }
}

struct StandingRow: View {
    let standing: Standing
    let player: Player
    var time: Double
    var highlight: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(rankMark)
                .font(Theme.Font.title(20))
                .foregroundStyle(highlight ? Theme.Color.legalGlow : Theme.Color.textSecondary)
                .frame(width: 30)

            PortraitRig(character: player.character,
                        mood: highlight ? .win : .idle,
                        size: 44,
                        time: time,
                        reduceMotion: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(standing.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(player.isHuman ? "你" : (player.difficulty?.displayName ?? "电脑"))
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            Spacer()

            Text(standing.isWinner ? "出完" : "\(standing.cardsLeft) 张")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(highlight ? Theme.Color.accent : Theme.Color.textPrimary.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(highlight ? Theme.Color.accent.opacity(0.12) : Theme.Color.panel))
    }

    private var rankMark: String {
        switch standing.rank {
        case 1: return "①"
        case 2: return "②"
        case 3: return "③"
        default: return "④"
        }
    }
}

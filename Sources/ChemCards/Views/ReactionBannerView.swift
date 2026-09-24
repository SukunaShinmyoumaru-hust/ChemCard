import SwiftUI

/// 出牌横幅：配平方程式 + 现象 + 一句易错点
struct ReactionBannerView: View {
    let event: GameState.PlayEvent
    var playerName: String
    var reduceMotion = false
    /// 竖屏在对手条带和容器条带之间只有百来 pt，字号和留白都收一档，别让横幅压到牌上
    var compact = false

    private var gap: CGFloat { compact ? 6 : 10 }
    private var chipSize: CGFloat { compact ? 10.5 : 12 }

    var body: some View {
        VStack(spacing: gap) {
            HStack(spacing: 8) {
                Text(playerName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
                Text(event.card.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.cardTop(event.card.category))
                Spacer()
                Image(systemName: "testtube.2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Color.cardTop(event.card.category))
            }

            if let reaction = event.reaction {
                Text(reaction.displayEquation)
                    .font(Theme.Font.formula(compact ? 22 : 30, weight: .bold))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(.vertical, 2)

                HStack(spacing: compact ? 5 : 8) {
                    Chip(text: reaction.rule, tint: Theme.Color.accent, size: chipSize)
                    ForEach(Array(reaction.phenomena.enumerated()), id: \.offset) { _, phenomenon in
                        Chip(text: phenomenon.text, tint: phenomenonTint(phenomenon), size: chipSize)
                    }
                    Chip(text: reaction.tier.displayName,
                         tint: reaction.tier == .senior ? SwiftUI.Color(red: 0.98, green: 0.72, blue: 0.36)
                                                        : Theme.Color.textSecondary,
                         size: chipSize)
                }

                if let note = reaction.note {
                    Text(note)
                        .font(.system(size: compact ? 11.5 : 12.5, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineSpacing(compact ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, compact ? 14 : 22)
        .padding(.vertical, compact ? 10 : 16)
        .frame(maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Theme.Color.cardBottom(event.card.category).opacity(0.92),
                                              SwiftUI.Color(white: 0.07).opacity(0.96)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.Color.cardTop(event.card.category).opacity(0.6), lineWidth: 1.2)
        )
        .shadow(color: .black.opacity(0.6), radius: 26, x: 0, y: 14)
        .transition(reduceMotion ? .opacity
                                 : .asymmetric(insertion: .scale(scale: 0.86).combined(with: .opacity),
                                               removal: .opacity))
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let reaction = event.reaction else {
            return "\(playerName) 打出\(event.card.title)"
        }
        return "\(playerName) 打出\(event.card.title)，\(reaction.displayEquation)，\(reaction.phenomenonText)"
    }

    private func phenomenonTint(_ phenomenon: Phenomenon) -> SwiftUI.Color {
        switch phenomenon {
        case .precipitate: return SwiftUI.Color(red: 0.72, green: 0.84, blue: 1.0)
        case .gas: return Theme.Color.accent
        case .heat, .flame: return SwiftUI.Color(red: 1.0, green: 0.58, blue: 0.36)
        case .noVisibleChange: return Theme.Color.textSecondary
        default: return SwiftUI.Color(red: 0.86, green: 0.72, blue: 1.0)
        }
    }
}

/// 注液泵/跳过/反向这类功能牌落地时的短提示
struct ActionNoticeView: View {
    let action: ActionCard
    var playerName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Color.cardTop(.function))
            Text("\(playerName) 使用了\(action.displayName)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Text(action.instruction)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(SwiftUI.Color.black.opacity(0.72)))
        .overlay(Capsule().strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

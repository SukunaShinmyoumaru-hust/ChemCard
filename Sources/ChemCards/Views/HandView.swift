import SwiftUI

/// 扇形手牌：悬停抬起、点按出牌。
/// 平时不标接得接不上（看颜色出牌学不到化学），只有 reveal 开着才标
struct HandView: View {
    let cards: [Card]
    let verdicts: [Int: Playability]
    var cardWidth: CGFloat
    var enabled: Bool
    var reduceMotion = false
    /// 永琳的诊断开着时才亮：合法牌发光、非法牌灰显
    var reveal = false
    var onPlay: (Card) -> Void

    @State private var hovered: Int?

    private var spacing: CGFloat {
        switch cards.count {
        case 0...6: return cardWidth * 0.80
        case 7...9: return cardWidth * 0.62
        case 10...13: return cardWidth * 0.50
        default: return cardWidth * 0.40
        }
    }

    private var mid: CGFloat { CGFloat(cards.count - 1) / 2 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(cards.enumerated()), id: \.element.uid) { index, card in
                cardView(card, index: index)
            }
        }
        .frame(width: max(cardWidth, CGFloat(cards.count) * spacing + cardWidth * 0.2),
               height: cardWidth / Theme.cardAspect + cardWidth * 0.42)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func cardView(_ card: Card, index: Int) -> some View {
        let verdict = verdicts[card.uid] ?? .illegal(reason: "")
        let look: CardLook
        if !enabled { look = .waiting }
        else if !reveal { look = .normal }
        else { look = verdict.isPlayable ? .legal : .illegal }
        let isOver = hovered == index
        // 悬停就抬：拿「抬不抬」报答案，等于没关高亮
        let lifted = isOver && enabled
        let offset = CGFloat(index) - mid
        let lift: CGFloat = lifted ? -cardWidth * 0.34 : 0

        return Button {
            onPlay(card)
        } label: {
            CardView(card: card, width: cardWidth, look: look)
        }
        .buttonStyle(.plain)
        .frame(width: cardWidth, height: cardWidth / Theme.cardAspect)
        .scaleEffect(lifted ? 1.10 : 1)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset) * 1.7), anchor: .bottom)
        .offset(x: offset * spacing,
                y: lift - (reduceMotion ? 0 : pow(abs(offset), 2) * cardWidth * 0.016))
        .zIndex(isOver ? 60 : Double(index))
        .onHover { inside in
            if inside { hovered = index } else if hovered == index { hovered = nil }
        }
        .help(enabled ? "点按出牌" : "还没轮到你出牌")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("点按出牌")
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: hovered)
    }
}


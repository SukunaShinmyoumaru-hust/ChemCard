import SwiftUI

/// 手机手牌条：一条横排叠牌。桌面那套扇形旋转在这里不能用——20 张牌转 ±16° 会互相切到，
/// 竖屏也没有横向余量给扇形的两端翘起。
struct PhoneHandBar: View {
    let cards: [Card]
    let verdicts: [Int: Playability]
    var cardWidth: CGFloat
    /// 相邻两张牌的中心距，由 SceneLayout.handLayout 决定；等于 cardWidth 就是不叠
    var step: CGFloat
    var enabled: Bool
    var reduceMotion = false
    /// 永琳的诊断开着时才亮：合法牌发光、非法牌灰显
    var reveal = false
    /// 选中那张抬起来。桌面靠悬停抬起，触屏没有悬停，只能由点选状态给
    var selected: Int?
    var onPlay: (Card) -> Void

    var body: some View {
        HStack(spacing: step - cardWidth) {
            ForEach(Array(cards.enumerated()), id: \.element.uid) { index, card in
                cardView(card, index: index)
            }
        }
        // 牌贴着底对齐，抬起的余量全留在上方，不然抬一张就顶穿上面那条带
        .frame(height: cardWidth / Theme.cardAspect + cardWidth * 0.42, alignment: .bottom)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: selected)
    }

    private func cardView(_ card: Card, index: Int) -> some View {
        let verdict = verdicts[card.uid] ?? .illegal(reason: "")
        let look: CardLook
        if !enabled { look = .waiting }
        else if !reveal { look = .normal }
        else { look = verdict.isPlayable ? .legal : .illegal }
        let lifted = selected == index && enabled

        return Button {
            onPlay(card)
        } label: {
            CardView(card: card, width: cardWidth, look: look)
        }
        .buttonStyle(.plain)
        .offset(y: lifted ? -cardWidth * 0.34 : 0)
        .scaleEffect(lifted ? 1.10 : 1)
        // 叠牌时后面的压住前面的，抬起的那张必须翻到最上层才点得到
        .zIndex(lifted ? 20 : CGFloat(index))
    }
}

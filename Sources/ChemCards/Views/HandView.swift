import SwiftUI

/// 扇形手牌：悬停抬起、合法牌发光、非法牌灰显，长按看牌面详情
struct HandView: View {
    let cards: [Card]
    let verdicts: [Int: Playability]
    var cardWidth: CGFloat
    var enabled: Bool
    var reduceMotion = false
    var onPlay: (Card) -> Void
    var onInspect: (Card) -> Void

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
        let look: CardLook = !enabled ? .waiting
            : (verdict.isPlayable ? (.legal) : (.illegal))
        let isOver = hovered == index
        // 只有轮到自己、且这张牌接得住，才抬起来
        let lifted = isOver && enabled && verdict.isPlayable
        let offset = CGFloat(index) - mid
        let lift: CGFloat = lifted ? -cardWidth * 0.34 : 0

        return ZStack(alignment: .topTrailing) {
            Button {
                onPlay(card)
            } label: {
                CardView(card: card, width: cardWidth, look: look)
            }
            .buttonStyle(.plain)

            if isOver {
                Button {
                    onInspect(card)
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: cardWidth * 0.20, weight: .semibold))
                        .foregroundStyle(.white, SwiftUI.Color.black.opacity(0.62))
                        .background(Circle().fill(SwiftUI.Color.black.opacity(0.28)))
                }
                .buttonStyle(.plain)
                .padding([.top, .trailing], cardWidth * 0.05)
                .help("检视这张牌")
                .accessibilityLabel("检视\(card.title)")
            }
        }
        .frame(width: cardWidth, height: cardWidth / Theme.cardAspect)
        .scaleEffect(lifted ? 1.10 : 1)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset) * 1.7), anchor: .bottom)
        .offset(x: offset * spacing,
                y: lift - (reduceMotion ? 0 : pow(abs(offset), 2) * cardWidth * 0.016))
        .zIndex(isOver ? 60 : Double(index))
        .onHover { inside in
            if inside { hovered = index } else if hovered == index { hovered = nil }
        }
        .contextMenu {
            Button("检视这张牌") { onInspect(card) }
        }
        .help(enabled ? "点按出牌 · 悬停后点 ⓘ 或右键看详情" : "还没轮到你出牌")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("点按出牌，右键查看牌面详情")
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: hovered)
    }
}

/// 牌面详情：物种卡展示类别/溶解性/活性/常见用途，功能牌展示规则说明
struct CardInspector: View {
    let card: Card
    let verdict: Playability
    var contents: [Species] = []
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(card.title)
                    .font(Theme.Font.title(24))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(card.formulaLine)
                    .font(Theme.Font.formula(22))
                    .foregroundStyle(Theme.Color.accent)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }

            chips

            if let species = card.species {
                VStack(alignment: .leading, spacing: 6) {
                    row("类别", species.category.displayName)
                    row("溶解性", species.solubility.rawValue)
                    row("知识层", species.tier.displayName)
                    if let nickname = species.nickname { row("俗称", nickname) }
                    if let note = species.note { row("备注", note) }
                }
            } else if let action = card.action {
                Text(action.instruction)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(Theme.Color.panelStroke)

            verdictLine
        }
        .padding(18)
        .frame(width: 380, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SwiftUI.Color(white: 0.11)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Theme.Color.panelStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 12)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            Chip(text: card.category.displayName, tint: Theme.Color.cardTop(card.category))
            if card.species != nil {
                Chip(text: "活性 \(card.activityScale)/9")
            }
            Spacer()
            Text(topLine)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    @ViewBuilder
    private var verdictLine: some View {
        switch verdict {
        case .reacts(let reaction):
            VStack(alignment: .leading, spacing: 4) {
                Text("可以反应 · \(reaction.rule)").font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.legalGlow)
                Text(reaction.displayEquation).font(Theme.Font.formula(15))
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(reaction.phenomenonText).font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        case .action(let action):
            Text("\(action.displayName)：任何时候都能打").font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Theme.Color.accent)
        case .illegal(let reason):
            VStack(alignment: .leading, spacing: 4) {
                Text("打不出去").font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Color.danger)
                Text(reason).font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private var topLine: String {
        guard !contents.isEmpty else { return "容器是空的" }
        let names = contents.reversed().map(\.name).joined(separator: "、")
        return contents.count > 1 ? "容器里：\(names)（任一种都能接）" : "容器里：\(names)"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

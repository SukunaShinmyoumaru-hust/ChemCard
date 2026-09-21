import SwiftUI

/// 中央反应区：左边牌堆、右边反应容器（一槽混合物），下面挂方向与注液泵指示
struct VesselPileView: View {
    @ObservedObject var state: GameState
    var cardWidth: CGFloat
    var drawEnabled: Bool
    var onDraw: () -> Void

    var body: some View {
        VStack(spacing: cardWidth * 0.18) {
            HStack(alignment: .top, spacing: cardWidth * 0.62) {
                stock
                vessel
            }
            chips
        }
    }

    // MARK: 牌堆

    private var stock: some View {
        Button(action: onDraw) {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: cardWidth * 0.19, weight: .semibold))
                        .foregroundStyle(Theme.Color.accent)
                    Text("牌堆 · \(state.stock.count) 张")
                        .font(.system(size: cardWidth * 0.17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                ZStack {
                    ForEach(0..<min(3, max(1, state.stock.count)), id: \.self) { layer in
                        CardBackView(width: cardWidth)
                            .offset(x: CGFloat(layer) * 2.4, y: -CGFloat(layer) * 2.4)
                    }
                }
                .frame(width: cardWidth * 1.12, height: cardWidth / Theme.cardAspect + 6)
            }
            .opacity(drawEnabled ? 1 : 0.55)
            .scaleEffect(drawEnabled ? 1 : 0.98)
        }
        .buttonStyle(PressableStyle())
        .disabled(!drawEnabled)
        .help(drawEnabled ? "摸一张牌" : "牌堆和容器都已无牌可回收")
        .overlay(alignment: .top) { preview }
    }

    /// 检液牌：翻开牌堆顶几张
    @ViewBuilder
    private var preview: some View {
        if !state.preview.isEmpty {
            HStack(spacing: 3) {
                ForEach(state.preview) { card in
                    CardView(card: card, width: cardWidth * 0.36)
                }
            }
            .offset(y: -cardWidth * 0.78)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: 容器

    /// 容器现在是一槽混合物：里面每一种物质都还能接牌，最新那一种画在最右边、最大最亮
    private var vessel: some View {
        let present = state.vesselCards
        return VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "testtube.2")
                    .font(.system(size: cardWidth * 0.19, weight: .semibold))
                    .foregroundStyle(Theme.Color.accent)
                Text(present.isEmpty
                        ? "反应容器 · 空的"
                        : "反应容器 · 现存 \(present.count) 种，接得住任意一种就能出牌")
                    .font(.system(size: cardWidth * 0.17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius * 1.5, style: .continuous)
                    .fill(LinearGradient(colors: [SwiftUI.Color.white.opacity(0.11),
                                                  SwiftUI.Color.black.opacity(0.26)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cardCornerRadius * 1.5, style: .continuous)
                        .strokeBorder(SwiftUI.Color.white.opacity(0.18), lineWidth: 1))

                if present.isEmpty {
                    Text("等着第一管试剂")
                        .font(.system(size: cardWidth * 0.16, design: .rounded))
                        .foregroundStyle(Theme.Color.textSecondary)
                } else {
                    HStack(alignment: .bottom, spacing: cardWidth * 0.08) {
                        ForEach(Array(present.enumerated()), id: \.element.uid) { index, card in
                            let newest = index == present.count - 1
                            CardView(card: card,
                                     width: cardWidth * (newest ? 1.08 : 0.76),
                                     look: newest ? .vessel : .normal)
                                .opacity(newest ? 1 : 0.66)
                                .saturation(newest ? 1 : 0.62)
                                .shadow(color: newest ? Theme.Color.legalGlow.opacity(0.35) : .clear,
                                        radius: newest ? 10 : 0)
                        }
                    }
                    .padding(.horizontal, cardWidth * 0.16)
                }
            }
            .frame(width: panelWidth, height: panelHeight)
        }
    }

    private var panelWidth: CGFloat { cardWidth * 3.7 }
    private var panelHeight: CGFloat { cardWidth / Theme.cardAspect * 1.18 + cardWidth * 0.2 }

    private var chips: some View {
        HStack(spacing: 8) {
            Chip(text: state.directionText, tint: Theme.Color.accent)
            if state.pendingDraw > 0 {
                Chip(text: "注液泵待结算 +\(state.pendingDraw)", tint: Theme.Color.danger)
            }
            if let top = state.topSpecies {
                Chip(text: top.tier.displayName, tint: Theme.Color.accent)
            }
        }
    }
}

struct Chip: View {
    let text: String
    var tint: SwiftUI.Color = Theme.Color.accent

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1))
            .background(Capsule().fill(SwiftUI.Color.black.opacity(0.28)))
    }
}

/// 容器里现存的某一种物质：动作条用它逐个标出来，玩家才知道自己能接哪几种
struct ContentsChip: View {
    let card: Card

    var body: some View {
        let tint = Theme.Color.cardTop(card.category)
        Text(card.title)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(SwiftUI.Color.black.opacity(0.34)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 0.8))
    }
}

/// 点下去会轻微缩一下的按钮样式
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

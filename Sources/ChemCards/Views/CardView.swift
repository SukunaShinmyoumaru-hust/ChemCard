import SwiftUI

/// 牌在视图里的状态：发光、灰显还是普通
enum CardLook: Equatable {
    case normal
    case legal
    case illegal
    /// 还没轮到自己：整排压暗，免得看着像能点
    case waiting
    case vessel
}

/// 程序化绘制的牌面：类别渐变 + 化学式 + 中文名 + 右上角活性刻度
struct CardView: View {
    let card: Card
    var width: CGFloat
    var look: CardLook = .normal

    private var height: CGFloat { width / Theme.cardAspect }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(Theme.Color.cardGradient(card.category))

            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(look == .legal ? 0.9 : 0.26),
                              lineWidth: look == .legal ? 2.2 : 1)

            content
        }
        .frame(width: width, height: height)
        .overlay(badge)
        .opacity(dimmed)
        .saturation(look == .illegal || look == .waiting ? 0.3 : 1)
        .shadow(color: glowColor.opacity(look == .legal ? 0.75 : 0.5),
                radius: look == .legal ? 14 : 5, x: 0, y: 3)
        .accessibilityLabel(accessibilityText)
    }

    private var dimmed: Double {
        switch look {
        case .illegal: return 0.6
        case .waiting: return 0.55
        default: return 1
        }
    }

    private var glowColor: SwiftUI.Color {
        if look == .legal { return Theme.Color.legalGlow }
        return .black
    }

    private var content: some View {
        VStack(spacing: width * 0.05) {
            Text(card.category.displayName)
                .font(.system(size: width * 0.13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

            Spacer(minLength: 0)

            if let action = card.action {
                Image(systemName: action.symbol)
                    .font(.system(size: width * 0.40, weight: .regular))
                    .foregroundStyle(.white)
                Text(action.displayName)
                    .font(.system(size: width * 0.16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(action.cornerMark)
                    .font(.system(size: width * 0.12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text(card.formulaLine)
                    .font(Theme.Font.formula(width * 0.25))
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Text(card.title)
                    .font(.system(size: width * 0.16, weight: .medium, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer(minLength: 0)
        }
        .padding(width * 0.09)
    }

    private var badge: some View {
        Text(card.action == nil ? "\(card.activityScale)" : "★")
            .font(Theme.Font.title(width * 0.26))
            .foregroundStyle(.white.opacity(0.95))
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(width * 0.08)
    }

    private var accessibilityText: String {
        if let species = card.species {
            return "\(species.name)，\(species.displayFormula)，\(card.category.displayName)，活性\(card.activityScale)"
        }
        return "\(card.title)功能牌，\(card.action?.instruction ?? "")"
    }
}

/// 牌背
struct CardBackView: View {
    var width: CGFloat
    var tint: SwiftUI.Color = Theme.Color.accent
    /// 座位上的迷你牌背只画轮廓，字太小会变成噪点
    var compact = false

    private var height: CGFloat { width / Theme.cardAspect }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [SwiftUI.Color(red: 0.16, green: 0.34, blue: 0.36),
                                              SwiftUI.Color(red: 0.05, green: 0.11, blue: 0.13)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .strokeBorder(tint.opacity(0.55), lineWidth: 1.2)
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius * 0.62, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.8)
                .padding(width * 0.07)
            if !compact {
                VStack(spacing: width * 0.06) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: width * 0.40, weight: .light))
                        .foregroundStyle(tint.opacity(0.9))
                    if width >= 92 {
                        Text("化学扑克牌")
                            .font(.system(size: width * 0.14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 3)
    }
}

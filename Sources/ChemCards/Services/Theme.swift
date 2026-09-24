import SwiftUI

enum Theme {
    #if canImport(AppKit)
    enum AppKitColor {
        static let windowBackground = NSColor(srgbRed: 0.055, green: 0.070, blue: 0.106, alpha: 1.0)
    }
    #endif

    enum Color {
        static let windowBackground = SwiftUI.Color(red: 0.055, green: 0.070, blue: 0.106)
        static let tableFelt = SwiftUI.Color(red: 0.086, green: 0.145, blue: 0.165)
        static let panel = SwiftUI.Color.white.opacity(0.06)
        static let panelStroke = SwiftUI.Color.white.opacity(0.14)
        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.66)
        static let accent = SwiftUI.Color(red: 0.36, green: 0.86, blue: 0.72)
        static let danger = SwiftUI.Color(red: 0.95, green: 0.42, blue: 0.42)
        static let legalGlow = SwiftUI.Color(red: 0.45, green: 0.95, blue: 0.65)
    }

    enum Font {
        static func formula(_ size: CGFloat, weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            SwiftUI.Font.system(size: size, weight: weight, design: .rounded)
        }
        static func title(_ size: CGFloat) -> SwiftUI.Font {
            SwiftUI.Font.system(size: size, weight: .bold, design: .rounded)
        }
    }

    static let cardCornerRadius: CGFloat = 12
    static let cardAspect: CGFloat = 5.0 / 7.0
}

extension Theme.Color {

    /// 类别配色：牌面渐变的亮端
    static func cardTop(_ category: CardCategory) -> SwiftUI.Color {
        switch category {
        case .acid: return SwiftUI.Color(red: 0.99, green: 0.72, blue: 0.28)
        case .base: return SwiftUI.Color(red: 0.42, green: 0.66, blue: 1.00)
        case .salt: return SwiftUI.Color(red: 0.26, green: 0.84, blue: 0.76)
        case .metal: return SwiftUI.Color(red: 0.66, green: 0.74, blue: 0.86)
        case .nonmetal: return SwiftUI.Color(red: 0.92, green: 0.44, blue: 0.70)
        case .metalOxide: return SwiftUI.Color(red: 0.90, green: 0.46, blue: 0.34)
        case .nonmetalOxide: return SwiftUI.Color(red: 0.40, green: 0.80, blue: 0.98)
        case .organic: return SwiftUI.Color(red: 0.52, green: 0.84, blue: 0.40)
        case .function: return SwiftUI.Color(red: 0.76, green: 0.56, blue: 1.00)
        }
    }

    /// 类别配色：牌面渐变的暗端
    static func cardBottom(_ category: CardCategory) -> SwiftUI.Color {
        switch category {
        case .acid: return SwiftUI.Color(red: 0.62, green: 0.30, blue: 0.05)
        case .base: return SwiftUI.Color(red: 0.14, green: 0.24, blue: 0.55)
        case .salt: return SwiftUI.Color(red: 0.05, green: 0.36, blue: 0.36)
        case .metal: return SwiftUI.Color(red: 0.20, green: 0.25, blue: 0.33)
        case .nonmetal: return SwiftUI.Color(red: 0.42, green: 0.12, blue: 0.32)
        case .metalOxide: return SwiftUI.Color(red: 0.40, green: 0.13, blue: 0.09)
        case .nonmetalOxide: return SwiftUI.Color(red: 0.08, green: 0.32, blue: 0.48)
        case .organic: return SwiftUI.Color(red: 0.14, green: 0.36, blue: 0.13)
        case .function: return SwiftUI.Color(red: 0.26, green: 0.14, blue: 0.48)
        }
    }

    static func cardGradient(_ category: CardCategory) -> LinearGradient {
        LinearGradient(colors: [cardTop(category), cardBottom(category)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

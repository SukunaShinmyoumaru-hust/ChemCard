import SwiftUI

/// 角色视觉参数：立绘缺图时程序化头像也用它，保证有图无图都是同一个人
struct CharacterSpec {
    let hair: SwiftUI.Color
    let hairShade: SwiftUI.Color
    let eye: SwiftUI.Color
    let accent: SwiftUI.Color
    let hairStyle: HairStyle
    let blinkPeriod: Double
    let phase: Double

    enum HairStyle {
        case ribbon        // 灵梦：两侧发束 + 大红蝴蝶结
        case hat           // 魔理沙：黑发 + 白色尖帽
        case sideBraid     // 妖梦：银白侧马尾
        case longBraid     // 早苗：长辫 + 发饰
    }

    init(_ character: CharacterID) {
        switch character {
        case .reimu:
            hair = SwiftUI.Color(red: 0.24, green: 0.13, blue: 0.14)
            hairShade = SwiftUI.Color(red: 0.12, green: 0.07, blue: 0.08)
            eye = SwiftUI.Color(red: 0.72, green: 0.16, blue: 0.20)
            accent = SwiftUI.Color(red: 0.95, green: 0.28, blue: 0.30)
            hairStyle = .ribbon
            blinkPeriod = 3.4
            phase = 0.0
        case .marisa:
            hair = SwiftUI.Color(red: 0.93, green: 0.84, blue: 0.55)
            hairShade = SwiftUI.Color(red: 0.72, green: 0.60, blue: 0.32)
            eye = SwiftUI.Color(red: 0.24, green: 0.44, blue: 0.80)
            accent = SwiftUI.Color(red: 0.98, green: 0.82, blue: 0.28)
            hairStyle = .hat
            blinkPeriod = 4.1
            phase = 1.1
        case .youmu:
            hair = SwiftUI.Color(red: 0.86, green: 0.93, blue: 0.92)
            hairShade = SwiftUI.Color(red: 0.60, green: 0.74, blue: 0.76)
            eye = SwiftUI.Color(red: 0.20, green: 0.62, blue: 0.55)
            accent = SwiftUI.Color(red: 0.32, green: 0.78, blue: 0.62)
            hairStyle = .sideBraid
            blinkPeriod = 3.0
            phase = 2.3
        case .sanae:
            hair = SwiftUI.Color(red: 0.30, green: 0.56, blue: 0.86)
            hairShade = SwiftUI.Color(red: 0.16, green: 0.34, blue: 0.60)
            eye = SwiftUI.Color(red: 0.86, green: 0.66, blue: 0.20)
            accent = SwiftUI.Color(red: 0.42, green: 0.72, blue: 0.98)
            hairStyle = .longBraid
            blinkPeriod = 4.6
            phase = 0.7
        }
    }

    static let skin = SwiftUI.Color(red: 1.00, green: 0.91, blue: 0.86)
    static let skinShade = SwiftUI.Color(red: 0.93, green: 0.79, blue: 0.73)
    static let blush = SwiftUI.Color(red: 1.00, green: 0.62, blue: 0.66)
}

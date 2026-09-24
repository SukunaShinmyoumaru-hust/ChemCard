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
        case ribbon        // 两侧发束 + 大蝴蝶结
        case hat           // 戴帽
        case sideBraid     // 单侧马尾
        case longBraid     // 长辫 + 发饰
    }

    init(_ character: CharacterID) {
        switch character {
        case .sanae:
            hair = SwiftUI.Color(red: 0.30, green: 0.56, blue: 0.86)
            hairShade = SwiftUI.Color(red: 0.16, green: 0.34, blue: 0.60)
            eye = SwiftUI.Color(red: 0.86, green: 0.66, blue: 0.20)
            accent = SwiftUI.Color(red: 0.42, green: 0.72, blue: 0.98)
            hairStyle = .longBraid
            blinkPeriod = 4.6
            phase = 0.7
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
        case .seiga:
            hair = SwiftUI.Color(red: 0.20, green: 0.16, blue: 0.22)
            hairShade = SwiftUI.Color(red: 0.09, green: 0.07, blue: 0.11)
            eye = SwiftUI.Color(red: 0.90, green: 0.42, blue: 0.24)
            accent = SwiftUI.Color(red: 0.86, green: 0.24, blue: 0.30)
            hairStyle = .hat
            blinkPeriod = 3.7
            phase = 2.6
        case .sakuya:
            hair = SwiftUI.Color(red: 0.86, green: 0.86, blue: 0.92)
            hairShade = SwiftUI.Color(red: 0.62, green: 0.63, blue: 0.72)
            eye = SwiftUI.Color(red: 0.34, green: 0.40, blue: 0.66)
            accent = SwiftUI.Color(red: 0.78, green: 0.80, blue: 0.90)
            hairStyle = .ribbon
            blinkPeriod = 4.3
            phase = 1.9
        case .cirno:
            hair = SwiftUI.Color(red: 0.52, green: 0.82, blue: 0.96)
            hairShade = SwiftUI.Color(red: 0.30, green: 0.60, blue: 0.80)
            eye = SwiftUI.Color(red: 0.16, green: 0.52, blue: 0.86)
            accent = SwiftUI.Color(red: 0.44, green: 0.82, blue: 1.00)
            hairStyle = .sideBraid
            blinkPeriod = 2.8
            phase = 3.3
        case .eirin:
            hair = SwiftUI.Color(red: 0.90, green: 0.90, blue: 0.94)
            hairShade = SwiftUI.Color(red: 0.66, green: 0.66, blue: 0.76)
            eye = SwiftUI.Color(red: 0.52, green: 0.34, blue: 0.72)
            accent = SwiftUI.Color(red: 0.72, green: 0.58, blue: 0.92)
            hairStyle = .longBraid
            blinkPeriod = 5.0
            phase = 0.3
        }
    }

    static let skin = SwiftUI.Color(red: 1.00, green: 0.91, blue: 0.86)
    static let skinShade = SwiftUI.Color(red: 0.93, green: 0.79, blue: 0.73)
    static let blush = SwiftUI.Color(red: 1.00, green: 0.62, blue: 0.66)
}

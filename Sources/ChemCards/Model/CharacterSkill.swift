import Foundation

/// 角色技能：一局一次，只有人类能用。
///
/// 三个技能刻意走功能牌同一条结算路径（`GameState.applyAction`）而不是各写一份：
/// 这样「梦想封印 ≡ 惰性气氛」这类等价关系由现有功能牌测试锁住，不会各自漂移。
enum Skill: String, CaseIterable, Identifiable {
    /// 博丽灵梦：下家跳过一回合
    case dreamSeal
    /// 雾雨魔理沙：往容器里轰进牌堆最上面那张物质牌，最早那种被挤出反应窗口
    case masterSpark
    /// 东风谷早苗：下家摸两张并跳过回合
    case miracle
    /// 鬼人正邪：出牌方向反向
    case reversal
    /// 十六夜咲夜：这一手再打一张
    case doublePlay
    /// 琪露诺：把自己冻住，跳过下一回合
    case selfFreeze
    /// 八意永琳：本回合把手牌按接得住与否标出来
    case reveal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dreamSeal: return "梦想封印"
        case .masterSpark: return "魔炮"
        case .miracle: return "引发奇迹"
        case .reversal: return "鬼之反转"
        case .doublePlay: return "The World"
        case .selfFreeze: return "完美冻结"
        case .reveal: return "万解诊断"
        }
    }

    /// 竖屏那颗按钮塞不下全名，手机上用两字短名，全名留给播报和规则卡
    var shortName: String {
        switch self {
        case .dreamSeal: return "封印"
        case .masterSpark: return "魔炮"
        case .miracle: return "奇迹"
        case .reversal: return "反转"
        case .doublePlay: return "双发"
        case .selfFreeze: return "冻结"
        case .reveal: return "诊断"
        }
    }

    var hint: String {
        switch self {
        case .dreamSeal: return "下家跳过一回合"
        case .masterSpark: return "容器顶上换一种物质"
        case .miracle: return "下家摸两张并跳过"
        case .reversal: return "出牌方向反向"
        case .doublePlay: return "这一手多出一张"
        case .selfFreeze: return "冻住自己，跳过下回合"
        case .reveal: return "本回合标出接得上的牌"
        }
    }

    /// 与哪张功能牌完全等价。三个技能共用同一条结算路径，等价关系由功能牌测试锁住。
    var action: ActionCard? {
        switch self {
        case .dreamSeal: return .inert
        case .miracle: return .pump
        case .reversal: return .reversible
        default: return nil
        }
    }

    /// 按钮上的符号：等价的三个技能直接借用那张功能牌的符号，一眼看得出谁是谁
    var symbol: String {
        switch self {
        case .dreamSeal: return ActionCard.inert.symbol
        case .miracle: return ActionCard.pump.symbol
        case .reversal: return ActionCard.reversible.symbol
        case .masterSpark: return "burst.fill"
        case .doublePlay: return "square.stack.3d.up.fill"
        case .selfFreeze: return "snowflake"
        case .reveal: return "eyeglasses"
        }
    }
}

extension CharacterID {
    /// 每个角色一个技能，一局限用一次
    var skill: Skill? {
        switch self {
        case .reimu: return .dreamSeal
        case .marisa: return .masterSpark
        case .sanae: return .miracle
        case .seiga: return .reversal
        case .sakuya: return .doublePlay
        case .cirno: return .selfFreeze
        case .eirin: return .reveal
        }
    }
}

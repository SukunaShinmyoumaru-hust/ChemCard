import SwiftUI

/// 手机与桌面的布局预算集中在这里。桌面的数字全部照抄原值，手机分支只做新增，
/// 所以调手机布局不会动到桌面一个像素。
enum SceneLayout {

    /// 编译期常量：macOS 上恒为 false，手机分支在桌面编译后会被折叠掉
    static var isPhone: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    // MARK: 主菜单

    static let menuPadding: CGFloat = isPhone ? 16 : 34
    static let menuSpacing: CGFloat = isPhone ? 12 : 20
    static let titleSize: CGFloat = isPhone ? 34 : 46
    static let subtitleSize: CGFloat = isPhone ? 12 : 13.5
    /// 桌面那行副标题原本就是单行，不加宽度约束；手机要折行才不溢出
    static let subtitleWidth: CGFloat? = isPhone ? 300 : nil

    static let panelPadding: CGFloat = isPhone ? 14 : 22
    static let panelSpacing: CGFloat = isPhone ? 12 : 16
    static let panelMaxWidth: CGFloat = isPhone ? .infinity : 780

    /// 七个角色按人头数排会折成 4+3，看着像缺一块；一律每行一个横条。
    static let characterColumns: Int = 1
    /// 横条立绘：7 行要和标题、对手强度、开始反应一起塞进 860pt 高的窗口，只能压到 48
    static let characterSpacing: CGFloat = 4
    static let portraitSize: CGFloat = isPhone ? 54 : 48

    static let difficultyChipWidth: CGFloat = isPhone ? 70 : 108
    static let difficultyChipSpacing: CGFloat = isPhone ? 8 : 10

    static let startButtonWidth: CGFloat? = isPhone ? nil : 180
    static let rulesButtonWidth: CGFloat? = isPhone ? nil : 140
    static let buttonHeight: CGFloat = isPhone ? 50 : 40

    // MARK: 手机牌桌

    static let bandSpacing: CGFloat = 8
    static let toolbarHeight: CGFloat = 44
    static let statusHeight: CGFloat = 30
    static let actionHeight: CGFloat = 52
    /// 三个对手挤一行：96 时名牌（五个字）刚好不互相盖住
    static let seatPortrait: CGFloat = 96
    static let seatSpacing: CGFloat = 10
    static let vesselCardWidth: CGFloat = 38
    static let maxHandCardWidth: CGFloat = 66
    /// 再小化学式就读不动了，宁可让牌互相叠起来
    static let handMinCardWidth: CGFloat = 34
    /// 手牌条左右各留 8，可用宽要先把这 16 扣掉
    static let handPadding: CGFloat = 16

    /// 手牌排布：先量屏宽，能全铺开就别叠。
    /// 桌面靠悬停把牌抬出来读，触屏没有这一步，被邻牌盖住的化学式就是读不到，
    /// 所以手机上「不叠」优先于「牌大」。铺不开才回到叠牌，按张数收紧步进。
    static func handLayout(count: Int, available: CGFloat) -> (cardWidth: CGFloat, step: CGFloat) {
        guard count > 1 else { return (maxHandCardWidth, maxHandCardWidth) }
        let plain = min(maxHandCardWidth, available / CGFloat(count))
        if plain >= handMinCardWidth { return (plain, plain) }
        let f = handStepFraction(count)
        let width = min(maxHandCardWidth, available / (f * CGFloat(count - 1) + 1))
        return (width, width * f)
    }

    /// 步进比例沿用 HandView 的档位：牌越多叠得越紧
    static func handStepFraction(_ count: Int) -> CGFloat {
        switch count {
        case 0...6: return 0.80
        case 7...9: return 0.62
        case 10...13: return 0.50
        default: return 0.40
        }
    }

    /// 手机上没有 560 / 380 的固定面板宽，一律按可用宽收，留 24 呼吸
    static func panelWidth(_ available: CGFloat, desktop: CGFloat) -> CGFloat {
        min(desktop, available - 24)
    }

    /// 规则卡：手机铺满安全区（nil = 跟随父容器），桌面固定 560×520
    static let rulesSize: CGSize? = isPhone ? nil : CGSize(width: 560, height: 520)
    static let rulesCorner: CGFloat = isPhone ? 0 : 18
    static let rulesExtraBottom: CGFloat = isPhone ? 12 : 0

    /// 桌面上技能有快捷键，光看按钮名猜不到发动的是本局唯一一次机会
    static let menuHint: String = "提示：接不上就摸牌；点一张牌，会写明它接不接得上、为什么不反应。"
        + (isPhone ? "" : "按 S 发动角色技能，一局一次。")

    /// 手机上这两行说明都挪进规则卡了：竖屏没有横向余量给尾注，多一行就少一屏
    static let portraitNote: String? = isPhone
        ? nil
        : "换图不用重新编译，覆盖 assets/Characters/<角色>/base.png 即可"

    static func difficultyNote(_ summary: String) -> String? {
        isPhone ? nil : summary
    }

    // 规则卡里两处只在桌面上成立的说法：空格快捷键、Application Support 路径
    static let verdictLine: String = "点一张牌，界面会写明它接不接得上、为什么不反应。"

    static let callLine: String = isPhone
        ? "手里只剩一张时必须先喊「反应!」再出牌，忘了罚抽一张。"
        : "手里只剩一张时必须先喊「反应!」（空格）再出牌，忘了罚抽一张。"

    static let assetLine: String = isPhone
        ? "牌桌立绘和背景可以替换：用「文件」App 把图片放进 ChemCards 目录的 Characters/<角色>/ 即可，不用重新编译。"
        : "牌桌立绘和背景可以替换：把图片放进 ~/Library/Application Support/ChemCards/assets/Characters/<角色>/ 即可，不用重新编译。"
}

extension View {
    /// 桌面继续用原来的固定 .frame(width:height:)，一个像素都不动；
    /// 手机传 nil 走 maxWidth —— 底色是围着 label 画的，
    /// 只把 .frame(maxWidth:) 加在 Button 外面撑不开那块颜色。
    @ViewBuilder func buttonSized(width: CGFloat?, height: CGFloat) -> some View {
        if let width {
            frame(width: width, height: height)
        } else {
            frame(maxWidth: .infinity, minHeight: height)
        }
    }
}


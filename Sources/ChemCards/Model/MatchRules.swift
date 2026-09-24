import Foundation

/// 一局牌的规则参数，集中放这里方便调平衡
struct MatchRules: Equatable {

    /// 起手手牌数
    var handSize = 7
    /// 容器里保留几种现存物质参与反应。越少越要算反应，越多越容易接上。
    /// 实测三档各 40 局（其余参数不变）：
    ///   1 槽 · 中位 573~575 手，40 局只有 5~13 局有人出完 —— 45% 的回合完全接不住，只能摸牌
    ///   2 槽 · 中位 45~213 手 —— 进阶/高级收束了，初级桌仍拖到 213 手、8/40 局卡壳
    ///   3 槽 · 中位 35~68 手，出完 40/40 —— 现在的取值
    /// 想收窄得先把反应表加厚（每种物质的伙伴牌中位 18/88，约 17% 命中率；UNO 是 85%）。
    /// 「不把答案摊开」这件事交给界面：平时不发光不灰显，见 HandView.reveal
    var vesselWindow = 3
    /// 手牌 ≤ 该值时必须喊「反应!」
    var reactionCallThreshold = 1
    /// 漏喊「反应!」罚抽张数
    var reactionCallPenalty = 1
    /// 注液泵给下家补的张数
    var pumpAmount = 2
    /// 回合数上限，防止三家互相「过」到永远
    var maxTurns = 600
    /// 初级 AI 忘记喊「反应!」的概率
    var noviceForgetCalls = 0.2

    static let standard = MatchRules()
    static let defaultSeed: UInt64 = 0x5EED_2026_0920
}

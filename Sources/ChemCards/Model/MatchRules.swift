import Foundation

/// 一局牌的规则参数，集中放这里方便调平衡
struct MatchRules: Equatable {

    /// 起手手牌数
    var handSize = 7
    /// 容器里保留几种现存物质参与反应：倒进去的试剂不会凭空消失，
    /// 最近这几样都能被下家拿去反应，牌桌才不会卡死
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

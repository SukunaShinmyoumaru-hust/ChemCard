import Foundation

enum GamePhase: Equatable {
    case playing
    /// 有玩家先出完手牌
    case finished(winner: Int)
    /// 达到回合上限，按剩牌数结算
    case stalled(turns: Int)

    var isOver: Bool {
        switch self {
        case .playing: return false
        case .finished, .stalled: return true
        }
    }

    var winner: Int? {
        if case .finished(let seat) = self { return seat }
        return nil
    }
}

/// 结算排名
struct Standing: Identifiable, Equatable {
    let rank: Int
    let seat: Int
    let name: String
    let cardsLeft: Int
    let isWinner: Bool

    var id: Int { seat }
}

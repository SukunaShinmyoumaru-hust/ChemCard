import XCTest
@testable import ChemCards

/// 平衡性：一局该多长、多少局真的有人出完手牌。物理混合被删掉之后，
/// 接不上只能摸牌或过牌，这两条兜底路线是否让牌局拖得太久，由这里把关。
final class BalanceTests: XCTestCase {

    private struct Sample {
        var turns: [Int] = []
        var finished = 0
        var stalled = 0
        var reactions = 0

        var median: Int {
            guard !turns.isEmpty else { return 0 }
            let sorted = turns.sorted()
            return sorted[sorted.count / 2]
        }

        var longest: Int { turns.max() ?? 0 }
    }

    private func sample(_ difficulty: AIDifficulty, games: Int) -> Sample {
        var out = Sample()
        for seed: UInt64 in 1...UInt64(games) {
            let state = GameState(players: MatchSetup.allAI(difficulty: difficulty), seed: seed)
            var turns = 0
            while !state.phase.isOver && turns <= MatchRules.standard.maxTurns {
                guard let decision = state.aiDecision() else { break }
                state.apply(decision)
                turns += 1
            }
            out.turns.append(turns)
            out.reactions += state.log.filter { $0.reaction != nil }.count
            switch state.phase {
            case .finished: out.finished += 1
            case .stalled: out.stalled += 1
            case .playing: out.stalled += 1
            }
        }
        return out
    }

    func testGamesConvergeInsteadOfGrinding() {
        for difficulty in AIDifficulty.allCases {
            let run = sample(difficulty, games: 40)
            print("[平衡] \(difficulty.displayName)：中位 \(run.median) 手，最长 \(run.longest) 手，"
                  + "出完 \(run.finished)/\(run.turns.count)，卡壳 \(run.stalled)，人均反应 \(run.reactions / max(1, run.turns.count))")
            XCTAssertGreaterThan(run.finished, run.turns.count * 8 / 10,
                                 "\(difficulty.displayName) 太多局没人出完手牌")
            XCTAssertLessThan(run.median, 180, "\(difficulty.displayName) 一局拖到中位数 \(run.median) 手")
        }
    }
}

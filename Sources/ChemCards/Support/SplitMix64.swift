import Foundation

/// 可重复随机数（SplitMix64）。牌堆洗牌与 AI 自动对局都必须能按种子复现，
/// 否则回归测试无法定位「第 37 手出的那张牌」。
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// [0, 1) 均匀分布，概率判定用
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// [0, bound) 均匀分布，bound <= 0 时返回 0
    mutating func nextInt(below bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        return Int(next() % UInt64(bound))
    }
}

import Foundation

/// 通用方程式配平器。
/// 规则引擎只负责给出「反应物 → 生成物」的化学式，系数由这里求解，
/// 从而保证任何一条规则的产物都天然满足质量守恒。
enum Balancer {

    private static var cache: [String: Equation?] = [:]
    private static let lock = NSLock()

    /// 求解最小正整数系数。找不到配平方案时返回 nil（说明该组产物写错了）。
    static func balance(lhs: [String], rhs: [String], condition: String? = nil) -> Equation? {
        let key = lhs.joined(separator: "+") + "=" + rhs.joined(separator: "+") + "|" + (condition ?? "")
        lock.lock()
        let cached = cache[key]
        lock.unlock()
        if let cached { return cached }

        let result = solve(lhs: lhs, rhs: rhs, condition: condition)

        lock.lock()
        cache[key] = result
        lock.unlock()
        return result
    }

    /// 按系数总和递增枚举，第一个解即为最简整数比（若有公因子，更小和的解必先出现）
    private static func solve(lhs: [String], rhs: [String], condition: String?) -> Equation? {
        let formulas = lhs + rhs
        guard !formulas.isEmpty, formulas.allSatisfy({ FormulaKit.parse($0) != nil }) else { return nil }

        let vectors: [[String: Int]] = formulas.map { FormulaKit.parse($0) ?? [:] }
        let signs: [Int] = Array(repeating: 1, count: lhs.count) + Array(repeating: -1, count: rhs.count)
        let elements = Array(Set(vectors.flatMap(\.keys))).sorted()
        let slots = formulas.count
        guard slots <= 7 else { return nil }

        var coefficients = [Int](repeating: 0, count: slots)

        func isBalanced() -> Bool {
            for element in elements {
                var total = 0
                for i in 0..<slots where coefficients[i] != 0 {
                    total += signs[i] * coefficients[i] * (vectors[i][element] ?? 0)
                }
                if total != 0 { return false }
            }
            return true
        }

        /// 剩余 `budget` 分给 `slots - index` 个槽位，每槽至少 1
        func search(_ index: Int, _ budget: Int) -> Bool {
            let remainingSlots = slots - index
            if remainingSlots == 1 {
                guard budget >= 1 else { return false }
                coefficients[index] = budget
                return isBalanced()
            }
            let upper = budget - remainingSlots + 1
            guard upper >= 1 else { return false }
            for value in 1...upper {
                coefficients[index] = value
                if search(index + 1, budget - value) { return true }
            }
            coefficients[index] = 0
            return false
        }

        for sum in slots...(slots * 9) {
            if search(0, sum) {
                let lhsTerms = zip(lhs, coefficients.prefix(lhs.count)).map { EquationTerm($0.1, $0.0) }
                let rhsTerms = zip(rhs, coefficients.suffix(rhs.count)).map { EquationTerm($0.1, $0.0) }
                return Equation(lhsTerms, rhsTerms, condition: condition)
            }
        }
        return nil
    }
}

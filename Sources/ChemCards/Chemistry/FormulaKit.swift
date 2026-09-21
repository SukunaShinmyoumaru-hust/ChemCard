import Foundation

/// 物质状态（用于方程式标注）
enum SubstanceState: String, Codable, Hashable {
    case solid      // 固体 s ↓
    case liquid     // 液体 l
    case gas        // 气体 g ↑
    case aqueous    // 溶液 aq
    case unspecified

    var symbol: String {
        switch self {
        case .solid: return "s"
        case .liquid: return "l"
        case .gas: return "g"
        case .aqueous: return "aq"
        case .unspecified: return ""
        }
    }

    /// 中文教学里的现象符号
    var phenomenonMark: String {
        switch self {
        case .solid: return "↓"
        case .gas: return "↑"
        default: return ""
        }
    }
}

/// 带电离子，用于「电荷交叉约简」自动生成盐的化学式
struct Ion: Hashable {
    let symbol: String      // "Cu" / "SO4" / "OH" / "NH4"
    let charge: Int         // 带符号：+2 / -1

    var magnitude: Int { abs(charge) }
    var isCation: Bool { charge > 0 }
    var isPolyatomic: Bool { (FormulaKit.parse(symbol)?.count ?? 1) > 1 }

    var display: String { FormulaKit.subscripted(symbol) + FormulaKit.superscriptCharge(charge) }
}

/// 方程式中的一项，如 `2H₂O`
struct EquationTerm: Hashable, Codable {
    var coefficient: Int
    var formula: String
    var state: SubstanceState = .unspecified
    /// 反应物中已有固体/气体时，生成物不再标 ↓ / ↑
    var showsMark: Bool = true

    init(_ coefficient: Int = 1, _ formula: String, state: SubstanceState = .unspecified) {
        self.coefficient = coefficient
        self.formula = formula
        self.state = state
    }

    var display: String {
        (coefficient > 1 ? "\(coefficient)" : "") + FormulaKit.subscripted(formula)
    }

    var displayWithState: String {
        display + (showsMark ? state.phenomenonMark : "")
    }

    var atomCounts: [String: Int] {
        (FormulaKit.parse(formula) ?? [:]).mapValues { $0 * coefficient }
    }
}

/// 已配平的化学方程式
struct Equation: Hashable, Codable {
    var lhs: [EquationTerm]
    var rhs: [EquationTerm]
    var condition: String?      // 点燃 / Δ / 催化剂 / 通电

    init(_ lhs: [EquationTerm], _ rhs: [EquationTerm], condition: String? = nil) {
        self.lhs = lhs
        self.rhs = rhs
        self.condition = condition
    }

    var display: String {
        let left = lhs.map(\.display).joined(separator: " + ")
        let right = rhs.map(\.displayWithState).joined(separator: " + ")
        let arrow = condition.map { " —\($0)→ " } ?? " → "
        return left + arrow + right
    }

    /// 各元素左右原子总数是否相等
    func isAtomBalanced() -> Bool {
        FormulaKit.aggregate(lhs) == FormulaKit.aggregate(rhs)
    }

    var unbalancedElements: [String] {
        let l = FormulaKit.aggregate(lhs)
        let r = FormulaKit.aggregate(rhs)
        return Set(l.keys).union(r.keys).filter { (l[$0] ?? 0) != (r[$0] ?? 0) }.sorted()
    }
}

/// 化学式解析 / 配平 / 渲染工具集
enum FormulaKit {

    // MARK: 解析

    /// 解析化学式为「元素 → 原子个数」。支持嵌套括号与点合物。
    /// `Ca(OH)2` → `[Ca:1, O:2, H:2]`；`CuSO4·5H2O` → `[Cu:1,S:1,O:9,H:10]`
    static func parse(_ formula: String) -> [String: Int]? {
        let parts = formula.trimmingCharacters(in: .whitespaces)
        guard !parts.isEmpty else { return nil }
        var total: [String: Int] = [:]
        for term in adductTerms(of: parts) {
            guard let sub = parseSegment(term.formula) else { return nil }
            for (element, count) in sub {
                total[element, default: 0] += count * term.coefficient
            }
        }
        return total.isEmpty ? nil : total
    }

    /// 点合物拆段：`CuSO4·5H2O` → `[("CuSO4",1), ("H2O",5)]`
    static func adductTerms(of formula: String) -> [(coefficient: Int, formula: String)] {
        var result: [(Int, String)] = []
        for raw in splitOnSeparators(formula) {
            let segment = raw.trimmingCharacters(in: .whitespaces)
            guard !segment.isEmpty else { continue }
            var idx = segment.startIndex
            var digits = ""
            while idx < segment.endIndex, segment[idx].isNumber {
                digits.append(segment[idx])
                idx = segment.index(after: idx)
            }
            let coefficient = Int(digits) ?? 1
            let rest = String(segment[idx...])
            guard !rest.isEmpty else { continue }
            result.append((coefficient, rest))
        }
        return result
    }

    private static func splitOnSeparators(_ formula: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var idx = formula.startIndex
        while idx < formula.endIndex {
            let c = formula[idx]
            if c == "·" || c == "*" || c == "•" {
                segments.append(current); current = ""
            } else if c == "." {
                // 只有 `.` 后面紧跟数字时才当作点合物分隔符（避免误伤小数）
                let next = formula.index(after: idx)
                if next < formula.endIndex, formula[next].isNumber {
                    segments.append(current); current = ""
                } else {
                    current.append(c)
                }
            } else {
                current.append(c)
            }
            idx = formula.index(after: idx)
        }
        segments.append(current)
        return segments.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// 解析单段化学式（不含点合物）
    private static func parseSegment(_ segment: String) -> [String: Int]? {
        let s = Array(segment)
        var i = 0
        var stack: [[String: Int]] = [[:]]

        func readNumber() -> Int {
            var digits = ""
            while i < s.count, s[i].isNumber {
                digits.append(s[i]); i += 1
            }
            return digits.isEmpty ? 1 : Int(digits) ?? 1
        }

        while i < s.count {
            let c = s[i]
            if c == "(" || c == "[" {
                stack.append([:])
                i += 1
            } else if c == ")" || c == "]" {
                i += 1
                let multiplier = readNumber()
                guard stack.count > 1 else { return nil }
                let group = stack.removeLast()
                guard !group.isEmpty else { return nil }
                for (element, count) in group {
                    stack[stack.count - 1][element, default: 0] += count * multiplier
                }
            } else if c.isUppercase {
                var symbol = String(c)
                i += 1
                while i < s.count, s[i].isLowercase {
                    symbol.append(s[i]); i += 1
                }
                let count = readNumber()
                stack[stack.count - 1][symbol, default: 0] += count
            } else {
                return nil     // 非法字符
            }
        }
        guard stack.count == 1, let top = stack.first, !top.isEmpty else { return nil }
        return top
    }

    // MARK: 交叉约简生成盐

    /// 由阳离子与阴离子按电荷交叉约简生成盐的化学式与系数。
    /// `Fe³⁺ + SO₄²⁻` → formula `Fe2(SO4)3`，cationCount 2，anionCount 3
    static func compound(fromCation cation: Ion, anion: Ion) -> (formula: String, cationCount: Int, anionCount: Int)? {
        guard cation.charge > 0, anion.charge < 0 else { return nil }
        let total = lcm(cation.magnitude, anion.magnitude)
        guard total > 0 else { return nil }
        let c = total / cation.magnitude
        let a = total / anion.magnitude
        // 有机酸根配一个阳离子时按书写习惯把酸根放前面（CH₃COONa）；个数 >1 仍是 Ca(CH₃COO)₂
        let formula = (c == 1 && organicFirstAnions.contains(anion.symbol))
            ? piece(anion, a) + cation.symbol
            : piece(cation, c) + piece(anion, a)
        return (formula, c, a)
    }

    private static let organicFirstAnions: Set<String> = ["CH3COO"]

    /// 单个离子片段：个数 > 1 时，原子团要加括号，单原子离子直接写下标
    private static func piece(_ ion: Ion, _ count: Int) -> String {
        guard count > 1 else { return ion.symbol }
        return ion.isPolyatomic ? "(\(ion.symbol))\(count)" : "\(ion.symbol)\(count)"
    }

    // MARK: 渲染

    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"
    ]

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"
    ]

    /// 把化学式中的数字转成 Unicode 下标：`H2SO4` → `H₂SO₄`
    static func subscripted(_ formula: String) -> String {
        String(formula.map { subscripts[$0] ?? $0 })
    }

    /// 电荷上标：`+2` → `²⁺`，`-1` → `⁻`
    static func superscriptCharge(_ charge: Int) -> String {
        guard charge != 0 else { return "" }
        let magnitude = abs(charge)
        let digits: String = magnitude == 1 ? "" : String(String(magnitude).map { superscripts[$0] ?? $0 })
        return String(digits) + (charge > 0 ? "⁺" : "⁻")
    }

    // MARK: 校验

    static func aggregate(_ terms: [EquationTerm]) -> [String: Int] {
        var total: [String: Int] = [:]
        for term in terms {
            for (element, count) in term.atomCounts {
                total[element, default: 0] += count
            }
        }
        return total
    }

    /// 方程式是否左右原子守恒
    static func isBalanced(_ equation: Equation) -> Bool {
        equation.isAtomBalanced()
    }

    // MARK: 数学

    static func gcd(_ a: Int, _ b: Int) -> Int {
        var (x, y) = (abs(a), abs(b))
        while y != 0 { (x, y) = (y, x % y) }
        return x == 0 ? 1 : x
    }

    static func lcm(_ a: Int, _ b: Int) -> Int {
        guard a != 0, b != 0 else { return max(a, b) }
        return abs(a * b) / gcd(a, b)
    }
}

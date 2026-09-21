import Foundation

/// 反应现象，同时决定得分加成
enum Phenomenon: Hashable, Codable {
    case precipitate(ColorHint)
    case gas
    case solidDissolves
    case solutionTurns(ColorHint)
    case colorChange(String)
    case heat
    case flame(ColorHint)
    case noVisibleChange

    var text: String {
        switch self {
        case .precipitate(let color): return "生成\(color.rawValue)沉淀↓"
        case .gas: return "放出气体↑"
        case .solidDissolves: return "固体逐渐溶解"
        case .solutionTurns(let color): return "溶液变为\(color.rawValue)"
        case .colorChange(let detail): return detail
        case .heat: return "反应放热"
        case .flame(let color): return "发出\(color.rawValue)火焰"
        case .noVisibleChange: return "无明显现象"
        }
    }

    var bonus: Int {
        switch self {
        case .precipitate: return 6
        case .gas: return 5
        case .solidDissolves: return 3
        case .solutionTurns: return 4
        case .colorChange: return 4
        case .heat: return 2
        case .flame: return 6
        case .noVisibleChange: return 0
        }
    }
}

/// 一次可出牌的化学反应
struct Reaction: Hashable, Codable {
    let equation: Equation
    let rule: String                  // 反应类型，如「中和反应」
    let phenomena: [Phenomenon]
    let tier: KnowledgeTier
    let note: String?

    static let basePoints = 10

    var points: Int {
        Reaction.basePoints + tier.bonusPoints + phenomena.reduce(0) { $0 + $1.bonus }
    }

    var displayEquation: String { equation.display }

    var phenomenonText: String {
        phenomena.isEmpty ? "无明显现象" : phenomena.map(\.text).joined(separator: "，")
    }
}

/// 反应物/生成物的一项（规则书写用）
struct ProductSpec {
    let formula: String
    let state: SubstanceState?

    init(_ formula: String, state: SubstanceState? = nil) {
        self.formula = formula
        self.state = state
    }
}

enum StateInference {
    static let gases: Set<String> = ["O2", "H2", "CO2", "SO2", "CO", "Cl2", "NH3", "N2", "CH4", "H2S"]

    static func of(formula: String) -> SubstanceState {
        if formula == "H2O" { return .liquid }
        if gases.contains(formula) { return .gas }
        if let species = Chemistry.species(formula: formula) {
            switch species.role {
            case .metal, .nonmetal, .basicOxide, .acidicOxide, .neutralOxide, .organic:
                return species.category == .organic && formula == "C2H5OH" ? .liquid : .solid
            default:
                return species.solubility == .insoluble ? .solid : .aqueous
            }
        }
        return .aqueous
    }
}

/// 把「反应物 → 生成物」组装成已配平、带状态标注的反应
enum ReactionFactory {

    static func make(lhs: [ProductSpec],
                     rhs: [ProductSpec],
                     rule: String,
                     phenomena: [Phenomenon],
                     tier: KnowledgeTier,
                     condition: String? = nil,
                     note: String? = nil) -> Reaction? {
        // 左右物种完全相同 = 什么都没发生，不能算一次反应
        let reactants = Dictionary(grouping: lhs.map(\.formula), by: { $0 }).mapValues(\.count)
        let products = Dictionary(grouping: rhs.map(\.formula), by: { $0 }).mapValues(\.count)
        guard reactants != products else { return nil }

        guard let balanced = Balancer.balance(
            lhs: lhs.map(\.formula),
            rhs: rhs.map(\.formula),
            condition: condition
        ) else { return nil }

        var equation = balanced
        for i in equation.lhs.indices {
            equation.lhs[i].state = lhs[i].state ?? StateInference.of(formula: equation.lhs[i].formula)
        }
        for i in equation.rhs.indices {
            equation.rhs[i].state = rhs[i].state ?? StateInference.of(formula: equation.rhs[i].formula)
        }

        // 反应物里已有固体则生成物中的固体不标 ↓，已有气体则气体不标 ↑
        let solidReactant = equation.lhs.contains { $0.state == .solid }
        let gasReactant = equation.lhs.contains { $0.state == .gas }
        for i in equation.rhs.indices {
            let state = equation.rhs[i].state
            if (state == .solid && solidReactant) || (state == .gas && gasReactant) {
                equation.rhs[i].showsMark = false
            }
        }
        return Reaction(equation: equation, rule: rule, phenomena: phenomena, tier: tier, note: note)
    }

    /// 由离子对推断生成物状态。微溶（Ag₂SO₄、Ca(OH)₂）不算沉淀，仍写成溶液
    static func saltState(cation: Ion, anion: Ion) -> SubstanceState {
        SolubilityTable.of(cation: cation, anion: anion) == .insoluble ? .solid : .aqueous
    }
}

import Foundation

/// 物质在反应规则中扮演的角色
enum ChemicalRole: Hashable {
    case acid(strong: Bool, oxidizing: Bool)   // oxidizing：浓硫酸、硝酸
    case base(strong: Bool)
    case salt
    case metal
    case nonmetal
    case basicOxide
    case acidicOxide
    case neutralOxide      // CO、NO 这类不成盐氧化物
    case water
    case organic
}

/// 一种化学物质（= 一张卡牌的牌面）
struct Species: Hashable, Identifiable {
    let id: String
    let formula: String          // ASCII 化学式，内部计算用
    let name: String             // 中文名
    let category: CardCategory
    var role: ChemicalRole = .salt
    var cation: Ion? = nil
    var anion: Ion? = nil
    var elementSymbol: String? = nil     // 单质元素符号，活动性判定用
    var isAmphoteric = false             // Al2O3 / Al(OH)3 之类
    var isReducing = false               // CO / H2 / C
    var declaredSolubility: Solubility? = nil
    var nickname: String? = nil          // 烧碱 / 纯碱 / 铁锈
    var tier: KnowledgeTier = .junior
    var note: String? = nil

    /// 离子型化合物的溶解性由溶解性表决定，避免手填与表不一致
    var solubility: Solubility {
        if let cation, let anion { return SolubilityTable.of(cation: cation, anion: anion) }
        return declaredSolubility ?? .insoluble
    }

    var activityRank: Int? { elementSymbol.flatMap(ActivitySeries.rank) }

    var displayFormula: String { FormulaKit.subscripted(formula) }

    var isMetal: Bool { role == .metal }
    var isNonmetal: Bool { role == .nonmetal }
    var isAcid: Bool { if case .acid = role { return true }; return false }
    var isBase: Bool { if case .base = role { return true }; return false }
    var isSalt: Bool { role == .salt }
    var isOxide: Bool { role == .basicOxide || role == .acidicOxide || role == .neutralOxide }
    var isAcidicOxide: Bool { role == .acidicOxide }
    var isBasicOxide: Bool { role == .basicOxide }
    var isWater: Bool { role == .water }
    var isOrganic: Bool { role == .organic }
    var oxidizingAcid: Bool {
        if case .acid(_, let oxidizing) = role { return oxidizing }
        return false
    }
    var strongAcid: Bool {
        if case .acid(let strong, _) = role { return strong }
        return false
    }
    var strongBase: Bool {
        if case .base(let strong) = role { return strong }
        return false
    }
    /// 盐溶液里的金属阳离子符号
    var metalSymbol: String? { cation?.symbol }
}

/// 常用离子
enum Ions {
    static let H = Ion(symbol: "H", charge: 1)
    static let OH = Ion(symbol: "OH", charge: -1)
    static let NH4 = Ion(symbol: "NH4", charge: 1)
    static let Na = Ion(symbol: "Na", charge: 1)
    static let K = Ion(symbol: "K", charge: 1)
    static let Ca = Ion(symbol: "Ca", charge: 2)
    static let Ba = Ion(symbol: "Ba", charge: 2)
    static let Mg = Ion(symbol: "Mg", charge: 2)
    static let Al = Ion(symbol: "Al", charge: 3)
    static let Zn = Ion(symbol: "Zn", charge: 2)
    static let Fe2 = Ion(symbol: "Fe", charge: 2)
    static let Fe3 = Ion(symbol: "Fe", charge: 3)
    static let Cu = Ion(symbol: "Cu", charge: 2)
    static let Ag = Ion(symbol: "Ag", charge: 1)

    static let Cl = Ion(symbol: "Cl", charge: -1)
    static let Br = Ion(symbol: "Br", charge: -1)
    static let I = Ion(symbol: "I", charge: -1)
    static let SO4 = Ion(symbol: "SO4", charge: -2)
    static let SO3 = Ion(symbol: "SO3", charge: -2)
    static let NO3 = Ion(symbol: "NO3", charge: -1)
    static let CO3 = Ion(symbol: "CO3", charge: -2)
    static let HCO3 = Ion(symbol: "HCO3", charge: -1)
    static let S = Ion(symbol: "S", charge: -2)
    static let SiO3 = Ion(symbol: "SiO3", charge: -2)
    static let PO4 = Ion(symbol: "PO4", charge: -3)
    static let AlO2 = Ion(symbol: "AlO2", charge: -1)
    static let Acetate = Ion(symbol: "CH3COO", charge: -1)
}

import Foundation

/// 金属活动性顺序表：K Ca Na Mg Al Zn Fe Sn Pb (H) Cu Hg Ag Pt Au
enum ActivitySeries {
    static let order = ["K", "Ca", "Na", "Mg", "Al", "Zn", "Fe", "Sn", "Pb", "H", "Cu", "Hg", "Ag", "Pt", "Au"]
    static let mnemonic = "钾钙钠镁铝、锌铁锡铅(氢)、铜汞银铂金"

    static func rank(_ symbol: String) -> Int? { order.firstIndex(of: symbol) }

    /// a 能否把 b 从其盐溶液中置换出来（a 更活泼）
    static func canDisplace(_ a: String, _ b: String) -> Bool {
        guard let ra = rank(a), let rb = rank(b) else { return false }
        return ra < rb
    }

    /// 能否置换稀酸中的氢
    static func reactsWithAcid(_ symbol: String) -> Bool {
        guard let r = rank(symbol), let h = rank("H") else { return false }
        return r < h
    }

    /// K/Ca/Na 太活泼，投入盐溶液会先与水反应，不算置换反应
    static func reactsWithWater(_ symbol: String) -> Bool {
        guard let r = rank(symbol) else { return false }
        return r <= rank("Na")!
    }
}

/// 酸性强弱序（按一级电离常数大致分档），「强酸制弱酸」的量化依据
enum AcidStrength {

    static let rank: [String: Int] = [
        "HCl": 6, "HBr": 6, "HI": 6, "HNO3": 6, "H2SO4": 6, "HClO4": 6,
        "H2SO3": 5, "H3PO4": 4, "HF": 3, "CH3COOH": 3,
        "H2CO3": 2, "H2S": 2,
        "HClO": 1, "C6H5OH": 1, "H2SiO3": 1
    ]

    static func rank(_ formula: String) -> Int { rank[formula] ?? 0 }

    /// a 能否把 b 从它的盐里赶出来
    static func stronger(_ a: String, than b: String) -> Bool { rank(a) > rank(b) }

    /// 极难溶、且不溶于强酸的沉淀：即使赶出的是强酸，反应也能进行（H₂S + CuSO₄ → CuS↓ + H₂SO₄）
    static let acidInsolubleSalts: Set<String> = ["CuS", "Ag2S", "HgS", "PbS", "AgCl", "BaSO4"]
}

/// 溶解性表（初中「钾钠铵硝皆可溶」口诀的规则化实现）
enum SolubilityTable {

    static let alkaliCations: Set<String> = ["K", "Na", "NH4"]

    /// 由阳离子 + 阴离子判断生成物是否可溶
    static func of(cation: Ion, anion: Ion) -> Solubility {
        of(cationSymbol: cation.symbol, anionSymbol: anion.symbol)
    }

    static func of(cationSymbol: String, anionSymbol: String) -> Solubility {
        let c = cationSymbol
        let a = anionSymbol

        // 阳离子是 H⁺ 时这是酸：除硅酸外常见酸皆可溶
        if c == "H" { return a == "SiO3" ? .insoluble : .soluble }

        // 钾、钠、铵盐与全部硝酸盐都可溶
        if alkaliCations.contains(c) { return .soluble }
        if a == "NO3" { return .soluble }

        switch a {
        case "OH":
            if c == "Ba" { return .soluble }
            if c == "Ca" { return .slight }       // 石灰水可溶，石灰乳浑浊
            return .insoluble
        case "Cl", "Br", "I":
            if c == "Ag" { return .insoluble }
            if c == "Pb" { return .slight }
            return .soluble
        case "SO4":
            if c == "Ba" || c == "Pb" { return .insoluble }
            if c == "Ca" || c == "Ag" { return .slight }
            return .soluble
        case "CO3", "PO4", "SiO3", "SO3":
            // 碳酸盐、磷酸盐、硅酸盐、亚硫酸盐只有钾钠铵可溶
            if c == "Mg" && a == "CO3" { return .slight }
            return .insoluble
        case "S":
            if c == "Ca" || c == "Ba" || c == "Mg" { return .soluble }
            return .insoluble
        case "HCO3", "C2H3O2", "AlO2":
            return .soluble
        default:
            return .soluble
        }
    }

    /// 复分解反应能否发生：生成物中必须有沉淀、气体或水
    static func canPrecipitate(cation: Ion, anion: Ion) -> Bool {
        of(cation: cation, anion: anion) == .insoluble
    }
}

/// 常见物质的颜色提示
enum ColorTable {
    /// 沉淀颜色
    static let precipitate: [String: ColorHint] = [
        "BaSO4": .white, "AgCl": .white, "CaCO3": .white, "BaCO3": .white,
        "Mg(OH)2": .white, "Al(OH)3": .white, "Zn(OH)2": .white,
        "H2SiO3": .white, "CaSO3": .white, "BaSO3": .white,
        "Cu(OH)2": .blue, "CuCO3": .blue,
        "Fe(OH)2": .paleGreen, "FeCO3": .paleGreen,
        "Fe(OH)3": .redBrown,
        "Fe2S3": .black, "CuS": .black, "FeS": .black, "Ag2S": .black, "PbS": .black,
        "S": .paleYellow, "Ag3PO4": .yellow, "AgI": .paleYellow, "AgBr": .paleYellow
    ]

    /// 析出金属单质的颜色（铜为紫红色，其余按银白色处理）
    static func metalColor(_ symbol: String) -> ColorHint {
        symbol == "Cu" ? .red : .silverWhite
    }

    /// 溶液颜色（按阳离子）
    static func solutionColor(ofCation ion: Ion) -> ColorHint? {
        switch (ion.symbol, ion.charge) {
        case ("Cu", 2): return .blue
        case ("Fe", 2): return .paleGreen
        case ("Fe", 3): return .yellow
        default: return nil
        }
    }
}

/// 元素常见化合价
enum Valence {
    /// 金属在置换/复分解中的常见价态
    static let defaultValence: [String: Int] = [
        "K": 1, "Na": 1, "Ca": 2, "Ba": 2, "Mg": 2, "Al": 3, "Zn": 2,
        "Fe": 2, "Cu": 2, "Hg": 2, "Ag": 1
    ]

    /// 遇强氧化剂时的价态（氯气把铁氧化到 +3）
    static let highValence: [String: Int] = ["Fe": 3, "Cu": 2, "Hg": 2]

    static func metalIon(_ symbol: String, strongOxidizer: Bool = false) -> Ion? {
        guard let base = defaultValence[symbol] else { return nil }
        let charge = strongOxidizer ? (highValence[symbol] ?? base) : base
        return Ion(symbol: symbol, charge: charge)
    }

    /// 卤素单质分子式，index 对应 ReactionRules 中的活动性序号
    static func halogenMolecule(_ index: Int) -> String? {
        switch index {
        case 0: return "Cl2"
        case 1: return "Br2"
        case 2: return "I2"
        default: return nil
        }
    }
}

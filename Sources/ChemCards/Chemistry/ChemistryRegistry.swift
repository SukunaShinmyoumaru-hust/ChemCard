import Foundation

/// 全部可入牌物种。规则引擎据此查表，新增物质只需在这里加一行。
enum Chemistry {

    static let all: [Species] = acids + bases + salts + metals + nonmetals + metalOxides + nonmetalOxides + organics

    static let byID: [String: Species] = Dictionary(
        all.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// 同一化学式可能对应多个物种（稀硫酸 / 浓硫酸），取登记顺序中第一个作为「代表」
    static let byFormula: [String: Species] = Dictionary(
        all.map { ($0.formula, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    static func species(_ id: String) -> Species? { byID[id] }
    static func species(formula: String) -> Species? { byFormula[formula] }

    /// 登记表中的顺序，用于把一对物种规范成确定的先后，保证方程式展示与调用顺序无关
    static let position: [String: Int] = Dictionary(
        all.enumerated().map { ($0.element.id, $0.offset) },
        uniquingKeysWith: { first, _ in first }
    )

    static func ordered(_ x: Species, _ y: Species) -> (Species, Species) {
        (position[x.id] ?? 0) <= (position[y.id] ?? 0) ? (x, y) : (y, x)
    }

    /// 生成物的展示名：登记表里有就用中文名，没有就退回化学式
    static func displayName(forFormula formula: String) -> String {
        byFormula[formula]?.name ?? formula
    }

    static let water = byID["h2o"]!
    static let hydrogen = byID["h2"]!
    static let oxygen = byID["o2"]!
    static let carbonDioxide = byID["co2"]!
    static let carbonMonoxide = byID["co"]!
    static let sulfurDioxide = byID["so2"]!

    // MARK: - 酸

    private static let acids: [Species] = [
        Species(id: "hcl", formula: "HCl", name: "盐酸", category: .acid, role: .acid(strong: true, oxidizing: false),
                cation: Ions.H, anion: Ions.Cl, note: "稀盐酸有弱氧化性（靠 H⁺），不能氧化 Cu"),
        Species(id: "h2so4", formula: "H2SO4", name: "稀硫酸", category: .acid, role: .acid(strong: true, oxidizing: false),
                cation: Ions.H, anion: Ions.SO4, note: "稀硫酸的氧化性来自 H⁺"),
        Species(id: "h2so4_conc", formula: "H2SO4", name: "浓硫酸", category: .acid, role: .acid(strong: true, oxidizing: true),
                cation: Ions.H, anion: Ions.SO4, tier: .senior, note: "浓硫酸强氧化性，与金属反应不放 H₂"),
        Species(id: "hno3", formula: "HNO3", name: "硝酸", category: .acid, role: .acid(strong: true, oxidizing: true),
                cation: Ions.H, anion: Ions.NO3, tier: .senior, note: "硝酸与金属反应生成水而不是氢气"),
        Species(id: "h2co3", formula: "H2CO3", name: "碳酸", category: .acid, role: .acid(strong: false, oxidizing: false),
                cation: Ions.H, anion: Ions.CO3, note: "碳酸不稳定，易分解为 CO₂ 与 H₂O"),
        Species(id: "h2so3", formula: "H2SO3", name: "亚硫酸", category: .acid, role: .acid(strong: false, oxidizing: false),
                cation: Ions.H, anion: Ions.SO3),
        Species(id: "h2s", formula: "H2S", name: "氢硫酸", category: .acid, role: .acid(strong: false, oxidizing: false),
                cation: Ions.H, anion: Ions.S, tier: .senior),
        Species(id: "h2sio3", formula: "H2SiO3", name: "硅酸", category: .acid, role: .acid(strong: false, oxidizing: false),
                cation: Ions.H, anion: Ions.SiO3, tier: .senior, note: "硅酸难溶于水，是白色胶状沉淀"),
        Species(id: "acoh", formula: "CH3COOH", name: "乙酸", category: .acid, role: .acid(strong: false, oxidizing: false),
                cation: Ions.H, anion: Ions.Acetate, nickname: "醋酸", note: "弱酸，但酸性强于碳酸")
    ]

    // MARK: - 碱

    private static let bases: [Species] = [
        Species(id: "naoh", formula: "NaOH", name: "氢氧化钠", category: .base, role: .base(strong: true),
                cation: Ions.Na, anion: Ions.OH, nickname: "烧碱"),
        Species(id: "koh", formula: "KOH", name: "氢氧化钾", category: .base, role: .base(strong: true),
                cation: Ions.K, anion: Ions.OH),
        Species(id: "caoh2", formula: "Ca(OH)2", name: "氢氧化钙", category: .base, role: .base(strong: true),
                cation: Ions.Ca, anion: Ions.OH, nickname: "熟石灰", note: "微溶，石灰水澄清、石灰乳浑浊"),
        Species(id: "baoh2", formula: "Ba(OH)2", name: "氢氧化钡", category: .base, role: .base(strong: true),
                cation: Ions.Ba, anion: Ions.OH),
        Species(id: "nh3h2o", formula: "NH3·H2O", name: "一水合氨", category: .base, role: .base(strong: false),
                cation: Ions.NH4, anion: Ions.OH, nickname: "氨水"),
        Species(id: "mgoh2", formula: "Mg(OH)2", name: "氢氧化镁", category: .base, role: .base(strong: false),
                cation: Ions.Mg, anion: Ions.OH),
        Species(id: "aloh3", formula: "Al(OH)3", name: "氢氧化铝", category: .base, role: .base(strong: false),
                cation: Ions.Al, anion: Ions.OH, isAmphoteric: true, tier: .senior,
                note: "两性氢氧化物，既能溶于酸又能溶于强碱"),
        Species(id: "feoh2", formula: "Fe(OH)2", name: "氢氧化亚铁", category: .base, role: .base(strong: false),
                cation: Ions.Fe2, anion: Ions.OH, note: "白色沉淀，迅速变灰绿最终变红褐"),
        Species(id: "feoh3", formula: "Fe(OH)3", name: "氢氧化铁", category: .base, role: .base(strong: false),
                cation: Ions.Fe3, anion: Ions.OH),
        Species(id: "cuoh2", formula: "Cu(OH)2", name: "氢氧化铜", category: .base, role: .base(strong: false),
                cation: Ions.Cu, anion: Ions.OH)
    ]

    // MARK: - 盐

    private static let salts: [Species] = [
        Species(id: "nacl", formula: "NaCl", name: "氯化钠", category: .salt, cation: Ions.Na, anion: Ions.Cl, nickname: "食盐"),
        Species(id: "kcl", formula: "KCl", name: "氯化钾", category: .salt, cation: Ions.K, anion: Ions.Cl),
        Species(id: "bacl2", formula: "BaCl2", name: "氯化钡", category: .salt, cation: Ions.Ba, anion: Ions.Cl),
        Species(id: "cacl2", formula: "CaCl2", name: "氯化钙", category: .salt, cation: Ions.Ca, anion: Ions.Cl),
        Species(id: "fecl3", formula: "FeCl3", name: "氯化铁", category: .salt, cation: Ions.Fe3, anion: Ions.Cl, tier: .senior),
        Species(id: "agno3", formula: "AgNO3", name: "硝酸银", category: .salt, cation: Ions.Ag, anion: Ions.NO3),
        Species(id: "na2co3", formula: "Na2CO3", name: "碳酸钠", category: .salt, cation: Ions.Na, anion: Ions.CO3, nickname: "纯碱"),
        Species(id: "caco3", formula: "CaCO3", name: "碳酸钙", category: .salt, cation: Ions.Ca, anion: Ions.CO3, nickname: "石灰石"),
        Species(id: "baco3", formula: "BaCO3", name: "碳酸钡", category: .salt, cation: Ions.Ba, anion: Ions.CO3),
        Species(id: "nahco3", formula: "NaHCO3", name: "碳酸氢钠", category: .salt, cation: Ions.Na, anion: Ions.HCO3, nickname: "小苏打"),
        Species(id: "na2so4", formula: "Na2SO4", name: "硫酸钠", category: .salt, cation: Ions.Na, anion: Ions.SO4),
        Species(id: "cuso4", formula: "CuSO4", name: "硫酸铜", category: .salt, cation: Ions.Cu, anion: Ions.SO4, nickname: "胆矾"),
        Species(id: "feso4", formula: "FeSO4", name: "硫酸亚铁", category: .salt, cation: Ions.Fe2, anion: Ions.SO4),
        Species(id: "fe2_so4_3", formula: "Fe2(SO4)3", name: "硫酸铁", category: .salt, cation: Ions.Fe3, anion: Ions.SO4, tier: .senior),
        Species(id: "al2_so4_3", formula: "Al2(SO4)3", name: "硫酸铝", category: .salt, cation: Ions.Al, anion: Ions.SO4, tier: .senior),
        Species(id: "nh42so4", formula: "(NH4)2SO4", name: "硫酸铵", category: .salt, cation: Ions.NH4, anion: Ions.SO4,
                note: "铵态氮肥，遇碱放出氨气"),
        Species(id: "nh4cl", formula: "NH4Cl", name: "氯化铵", category: .salt, cation: Ions.NH4, anion: Ions.Cl),
        Species(id: "kno3", formula: "KNO3", name: "硝酸钾", category: .salt, cation: Ions.K, anion: Ions.NO3,
                note: "钾盐、钠盐、铵盐、硝酸盐都可溶，几乎不参与复分解"),
        Species(id: "na2sio3", formula: "Na2SiO3", name: "硅酸钠", category: .salt, cation: Ions.Na, anion: Ions.SiO3,
                nickname: "水玻璃", tier: .senior),
        Species(id: "na2so3", formula: "Na2SO3", name: "亚硫酸钠", category: .salt, cation: Ions.Na, anion: Ions.SO3, tier: .senior),
        Species(id: "ki", formula: "KI", name: "碘化钾", category: .salt, cation: Ions.K, anion: Ions.I, tier: .senior),
        Species(id: "kbr", formula: "KBr", name: "溴化钾", category: .salt, cation: Ions.K, anion: Ions.Br, tier: .senior),
        Species(id: "baso4", formula: "BaSO4", name: "硫酸钡", category: .salt, cation: Ions.Ba, anion: Ions.SO4,
                nickname: "钡餐", note: "既不溶于水也不溶于酸，几乎无法被反应掉")
    ]

    // MARK: - 金属单质

    private static let metals: [Species] = [
        metal("k", "K", "钾", note: "太活泼，投入盐溶液先与水反应"),
        metal("ca", "Ca", "钙"),
        metal("na", "Na", "钠", note: "保存在煤油中，与水剧烈反应"),
        metal("mg", "Mg", "镁"),
        metal("al", "Al", "铝", note: "表面致密氧化膜使其耐腐蚀"),
        metal("zn", "Zn", "锌"),
        metal("fe", "Fe", "铁"),
        metal("cu", "Cu", "铜", note: "排在氢之后，不能置换稀酸中的氢"),
        metal("hg", "Hg", "汞"),
        metal("ag", "Ag", "银", note: "很不活泼，只能被氧化性酸溶解")
    ]

    private static func metal(_ id: String, _ symbol: String, _ name: String, tier: KnowledgeTier = .junior, note: String? = nil) -> Species {
        Species(id: id, formula: symbol, name: name, category: .metal, role: .metal, elementSymbol: symbol, tier: tier, note: note)
    }

    // MARK: - 非金属单质

    private static let nonmetals: [Species] = [
        Species(id: "o2", formula: "O2", name: "氧气", category: .nonmetal, role: .nonmetal, elementSymbol: "O"),
        Species(id: "h2", formula: "H2", name: "氢气", category: .nonmetal, role: .nonmetal, elementSymbol: "H", isReducing: true),
        Species(id: "c", formula: "C", name: "木炭", category: .nonmetal, role: .nonmetal, elementSymbol: "C", isReducing: true, nickname: "碳"),
        Species(id: "s", formula: "S", name: "硫磺", category: .nonmetal, role: .nonmetal, elementSymbol: "S"),
        Species(id: "p", formula: "P", name: "红磷", category: .nonmetal, role: .nonmetal, elementSymbol: "P"),
        Species(id: "cl2", formula: "Cl2", name: "氯气", category: .nonmetal, role: .nonmetal, elementSymbol: "Cl", tier: .senior,
                note: "卤素活动性 Cl₂ > Br₂ > I₂，可置换溴碘")
    ]

    // MARK: - 金属氧化物

    private static let metalOxides: [Species] = [
        Species(id: "na2o", formula: "Na2O", name: "氧化钠", category: .metalOxide, role: .basicOxide, cation: Ions.Na),
        Species(id: "k2o", formula: "K2O", name: "氧化钾", category: .metalOxide, role: .basicOxide, cation: Ions.K),
        Species(id: "cao", formula: "CaO", name: "氧化钙", category: .metalOxide, role: .basicOxide, cation: Ions.Ca, nickname: "生石灰"),
        Species(id: "mgo", formula: "MgO", name: "氧化镁", category: .metalOxide, role: .basicOxide, cation: Ions.Mg),
        Species(id: "cuo", formula: "CuO", name: "氧化铜", category: .metalOxide, role: .basicOxide, cation: Ions.Cu),
        Species(id: "fe2o3", formula: "Fe2O3", name: "氧化铁", category: .metalOxide, role: .basicOxide, cation: Ions.Fe3, nickname: "铁锈"),
        Species(id: "fe3o4", formula: "Fe3O4", name: "四氧化三铁", category: .metalOxide, role: .basicOxide, nickname: "磁铁矿",
                note: "FeO 与 Fe₂O₃ 的混合价态氧化物，产物按精选反应表处理"),
        Species(id: "al2o3", formula: "Al2O3", name: "氧化铝", category: .metalOxide, role: .basicOxide, cation: Ions.Al,
                isAmphoteric: true, tier: .senior, note: "两性氧化物，既能溶于酸又能溶于强碱")
    ]

    // MARK: - 非金属氧化物

    private static let nonmetalOxides: [Species] = [
        Species(id: "co2", formula: "CO2", name: "二氧化碳", category: .nonmetalOxide, role: .acidicOxide, anion: Ions.CO3),
        Species(id: "so2", formula: "SO2", name: "二氧化硫", category: .nonmetalOxide, role: .acidicOxide, anion: Ions.SO3,
                note: "刺激性气味，是形成酸雨的主因"),
        Species(id: "so3", formula: "SO3", name: "三氧化硫", category: .nonmetalOxide, role: .acidicOxide, anion: Ions.SO4, tier: .senior),
        Species(id: "sio2", formula: "SiO2", name: "二氧化硅", category: .nonmetalOxide, role: .acidicOxide, anion: Ions.SiO3,
                nickname: "石英", note: "不溶于水，但能与强碱、碱性氧化物反应"),
        Species(id: "p2o5", formula: "P2O5", name: "五氧化二磷", category: .nonmetalOxide, role: .acidicOxide, anion: Ions.PO4),
        Species(id: "co", formula: "CO", name: "一氧化碳", category: .nonmetalOxide, role: .neutralOxide, isReducing: true,
                note: "不成盐氧化物，不与碱反应，但能还原金属氧化物"),
        Species(id: "h2o", formula: "H2O", name: "水", category: .nonmetalOxide, role: .water, nickname: "万能溶剂")
    ]

    // MARK: - 有机物

    private static let organics: [Species] = [
        Species(id: "c2h5oh", formula: "C2H5OH", name: "乙醇", category: .organic, role: .organic, nickname: "酒精", tier: .senior),
        Species(id: "c6h5oh", formula: "C6H5OH", name: "苯酚", category: .organic, role: .organic, tier: .senior,
                note: "有弱酸性，能与 NaOH 反应"),
        Species(id: "ch4", formula: "CH4", name: "甲烷", category: .organic, role: .organic, nickname: "天然气", tier: .senior)
    ]
}

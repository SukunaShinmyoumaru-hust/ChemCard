import Foundation

/// 无法由通式推导、需要显式写出反应物的反应（配平仍由 Balancer 自动完成）
struct CuratedReaction {
    let a: String             // 物种 id
    let b: String
    let products: [String]
    let rule: String
    var phenomena: [Phenomenon] = []
    var tier: KnowledgeTier = .senior
    var condition: String? = nil
    var note: String? = nil
}

enum CuratedReactions {

    static let table: [CuratedReaction] = [
        CuratedReaction(
            a: "c", b: "h2so4_conc", products: ["CO2", "SO2", "H2O"],
            rule: "浓硫酸氧化非金属", phenomena: [.gas, .heat], tier: .senior, condition: "浓硫酸、加热",
            note: "碳被浓硫酸氧化，放出 CO₂ 与 SO₂ 混合气体"),
        CuratedReaction(
            a: "co2", b: "c", products: ["CO"],
            rule: "二氧化碳被碳还原", phenomena: [.gas], tier: .senior, condition: "高温",
            note: "CO₂ + C —高温→ 2CO，吸热反应"),
        CuratedReaction(
            a: "fe", b: "fecl3", products: ["FeCl2"],
            rule: "铁与氯化铁化合", phenomena: [.solutionTurns(.paleGreen)], tier: .senior,
            note: "Fe + 2FeCl₃ → 3FeCl₂，同种元素不同价态归中"),
        CuratedReaction(
            a: "h2", b: "cl2", products: ["HCl"],
            rule: "氢气在氯气中燃烧", phenomena: [.flame(.paleYellow), .gas], tier: .senior, condition: "点燃",
            note: "H₂ 在 Cl₂ 中安静燃烧，集气瓶口有白雾"),
        CuratedReaction(
            a: "h2s", b: "so2", products: ["S", "H2O"],
            rule: "归中反应", phenomena: [.precipitate(.paleYellow)], tier: .senior,
            note: "2H₂S + SO₂ → 3S↓ + 2H₂O，硫的两种价态归中为 0 价"),
        CuratedReaction(
            a: "caco3", b: "sio2", products: ["CaSiO3", "CO2"],
            rule: "造渣反应", phenomena: [.gas], tier: .senior, condition: "高温",
            note: "高炉炼铁中用石灰石除去脉石 SiO₂"),
        CuratedReaction(
            a: "fe3o4", b: "hcl", products: ["FeCl2", "FeCl3", "H2O"],
            rule: "四氧化三铁与酸", phenomena: [.solidDissolves, .solutionTurns(.yellow)], tier: .senior,
            note: "Fe₃O₄ 含 +2 与 +3 两种价态，与盐酸反应同时生成 FeCl₂ 和 FeCl₃"),
        CuratedReaction(
            a: "fe3o4", b: "h2so4", products: ["FeSO4", "Fe2(SO4)3", "H2O"],
            rule: "四氧化三铁与酸", phenomena: [.solidDissolves, .solutionTurns(.yellow)], tier: .senior,
            note: "Fe₃O₄ 与稀硫酸反应生成 FeSO₄ 与 Fe₂(SO₄)₃"),
        CuratedReaction(
            a: "co", b: "fe2o3", products: ["Fe", "CO2"],
            rule: "高炉炼铁", phenomena: [.gas, .colorChange("红色粉末逐渐变黑")], tier: .senior, condition: "高温",
            note: "3CO + Fe₂O₃ —高温→ 2Fe + 3CO₂，工业炼铁原理"),
        CuratedReaction(
            a: "al", b: "fe2o3", products: ["Al2O3", "Fe"],
            rule: "铝热反应", phenomena: [.flame(.white), .heat, .colorChange("剧烈燃烧、火星四射，熔融铁水流出")],
            tier: .senior, condition: "高温、镁条引燃",
            note: "2Al + Fe₂O₃ —高温→ Al₂O₃ + 2Fe，用于焊接铁轨"),
        CuratedReaction(
            a: "naoh", b: "c6h5oh", products: ["C6H5ONa", "H2O"],
            rule: "苯酚的酸性", phenomena: [.solidDissolves], tier: .senior,
            note: "苯酚有弱酸性（石炭酸），能与 NaOH 反应但不能使指示剂变色"),
        CuratedReaction(
            a: "acoh", b: "c2h5oh", products: ["CH3COOC2H5", "H2O"],
            rule: "酯化反应", phenomena: [.colorChange("生成有果香味的油状液体")], tier: .senior, condition: "浓硫酸、加热",
            note: "酸脱羟基、醇脱氢，浓硫酸作催化剂并吸水"),
        CuratedReaction(
            a: "cuso4", b: "h2o", products: ["CuSO4·5H2O"],
            rule: "检验水的存在", phenomena: [.colorChange("白色粉末变为蓝色")], tier: .senior,
            note: "无水 CuSO₄ 遇水生成胆矾，用于检验水分"),
        CuratedReaction(
            a: "fecl3", b: "nahco3", products: ["Fe(OH)3", "CO2", "NaCl"],
            rule: "双水解", phenomena: [.precipitate(.redBrown), .gas], tier: .senior,
            note: "Fe³⁺ 与 HCO₃⁻ 互相促进水解，泡沫灭火器原理"),
        CuratedReaction(
            a: "al2_so4_3", b: "nahco3", products: ["Al(OH)3", "CO2", "Na2SO4"],
            rule: "双水解", phenomena: [.precipitate(.white), .gas], tier: .senior,
            note: "Al³⁺ 与 HCO₃⁻ 双水解生成 Al(OH)₃ 与 CO₂"),
        CuratedReaction(
            a: "mg", b: "co2", products: ["MgO", "C"],
            rule: "镁在二氧化碳中燃烧", phenomena: [.flame(.white), .colorChange("瓶壁出现黑色炭粒")],
            tier: .senior, condition: "点燃",
            note: "2Mg + CO₂ —点燃→ 2MgO + C，所以活泼金属火灾不能用 CO₂ 灭火器"),
        CuratedReaction(
            a: "na", b: "c2h5oh", products: ["C2H5ONa", "H2"],
            rule: "钠置换醇羟基", phenomena: [.gas], tier: .senior,
            note: "2C₂H₅OH + 2Na → 2C₂H₅ONa + H₂↑，反应比水缓和"),
        CuratedReaction(
            a: "hno3", b: "na2so3", products: ["Na2SO4", "NO", "H2O"],
            rule: "硝酸氧化亚硫酸盐", phenomena: [.gas, .colorChange("无色气体逸出后在瓶口变为红棕色")],
            tier: .senior,
            note: "硝酸把 SO₃²⁻ 氧化成 SO₄²⁻，放出的是 NO 而不是 SO₂，按复分解写就错了"),
        CuratedReaction(
            a: "cu", b: "s", products: ["Cu2S"],
            rule: "金属与卤素/硫", phenomena: [.heat], tier: .senior, condition: "加热",
            note: "硫的氧化性弱，只能把铜氧化到 +1：2Cu + S —加热→ Cu₂S（氯气才到 +3）"),
        CuratedReaction(
            a: "kno3", b: "h2so4_conc", products: ["KHSO4", "HNO3"],
            rule: "高沸点酸制挥发酸", phenomena: [.colorChange("逸出硝酸蒸气，冷却后得浓硝酸")],
            tier: .senior, condition: "微热",
            note: "硝酸盐与浓硫酸微热蒸出 HNO₃，强热会分解，所以只能微热"),
        CuratedReaction(
            a: "baso4", b: "na2co3", products: ["BaCO3", "Na2SO4"],
            rule: "沉淀转化", phenomena: [], tier: .senior, condition: "饱和Na₂CO₃溶液、反复",
            note: "BaSO₄ 饱和碳酸钠里反复转化为 BaCO₃，后者能溶于盐酸，钡餐就是这样处理的")
    ]

    private static let index: [String: CuratedReaction] = Dictionary(
        table.map { (key(forID: $0.a, $0.b), $0) },
        uniquingKeysWith: { first, _ in first }
    )

    static func key(forID a: String, _ b: String) -> String {
        [a, b].sorted().joined(separator: "|")
    }

    static func lookup(_ x: Species, _ y: Species) -> Reaction? {
        guard let entry = index[key(forID: x.id, y.id)] else { return nil }
        let ids = [entry.a, entry.b]
        // 保持书写顺序，让方程式与教材一致（如 Fe + H₂SO₄(浓)）
        let reactants = (x.id == ids.first ? [x, y] : [y, x]).map(\.formula)
        return ReactionFactory.make(
            lhs: reactants.map { ProductSpec($0) },
            rhs: entry.products.map { ProductSpec($0) },
            rule: entry.rule,
            phenomena: entry.phenomena,
            tier: entry.tier,
            condition: entry.condition,
            note: entry.note
        )
    }
}

/// 明确「不反应」的组合，优先于规则匹配，用于还原真实考点
enum BlockedReactions {
    static let passivationMetals: Set<String> = ["fe", "al"]
    static let passivationAcids: Set<String> = ["h2so4_conc", "hno3"]

    /// 氧化性酸遇到这些还原性酸根时发生的是氧化还原，通式规则会写出不存在的复分解产物
    static let oxidizingAcids: Set<String> = ["h2so4_conc", "hno3"]
    static let reducingAnions: [String: String] = [
        "SO3": "亚硫酸根", "S": "硫离子", "Br": "溴离子", "I": "碘离子"
    ]

    static func reason(_ x: Species, _ y: Species) -> String? {
        let pair = [x, y]

        if let metal = pair.first(where: { passivationMetals.contains($0.id) }),
           let acid = pair.first(where: { passivationAcids.contains($0.id) }),
           metal.id != acid.id {
            return "常温下 \(metal.name) 在 \(acid.name) 中发生钝化，表面生成致密氧化膜阻止反应继续"
        }

        if let acid = pair.first(where: { oxidizingAcids.contains($0.id) }),
           let other = pair.first(where: { $0.id != acid.id }),
           let anion = other.anion?.symbol,
           let anionName = reducingAnions[anion] {
            return "\(acid.name) 有强氧化性，会先把\(other.name)里的\(anionName)氧化，发生的是氧化还原而不是复分解"
        }

        return nil
    }
}

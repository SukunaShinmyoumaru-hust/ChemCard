import Foundation

/// 一条反应规则：给定有序的一对物种，若能反应则返回配平好的反应
struct ReactionRule {
    let name: String
    let apply: (Species, Species) -> Reaction?
}

enum ReactionRules {

    static let all: [ReactionRule] = [
        ReactionRule(name: "中和反应", apply: acidBase),
        ReactionRule(name: "碱性氧化物与酸", apply: acidBasicOxide),
        ReactionRule(name: "金属与酸置换", apply: metalAcid),
        ReactionRule(name: "氧化性酸溶解金属", apply: metalOxidizingAcid),
        ReactionRule(name: "活泼金属与水", apply: activeMetalWater),
        ReactionRule(name: "酸性氧化物与碱", apply: acidicOxideBase),
        ReactionRule(name: "酸性氧化物与水", apply: acidicOxideWater),
        ReactionRule(name: "碱性氧化物与水", apply: basicOxideWater),
        ReactionRule(name: "盐与酸", apply: acidSalt),
        ReactionRule(name: "碱与盐", apply: baseSalt),
        ReactionRule(name: "盐与盐", apply: saltSalt),
        ReactionRule(name: "金属与盐置换", apply: metalSalt),
        ReactionRule(name: "酸式盐与碱", apply: acidSaltWithBase),
        ReactionRule(name: "两性物质与强碱", apply: amphotericWithBase),
        ReactionRule(name: "酸性氧化物与碱性氧化物", apply: acidicWithBasicOxide),
        ReactionRule(name: "金属燃烧", apply: metalOxygen),
        ReactionRule(name: "非金属燃烧", apply: nonmetalOxygen),
        ReactionRule(name: "有机物燃烧", apply: organicCombustion),
        ReactionRule(name: "还原剂还原金属氧化物", apply: reductionByGasOrCarbon),
        ReactionRule(name: "金属与卤素/硫", apply: metalWithNonmetal),
        ReactionRule(name: "卤素置换", apply: halogenDisplacement)
    ]

    // MARK: - 公共辅助

    private static func salt(_ cation: Ion, _ anion: Ion) -> ProductSpec? {
        guard let made = FormulaKit.compound(fromCation: cation, anion: anion) else { return nil }
        return ProductSpec(made.formula, state: ReactionFactory.saltState(cation: cation, anion: anion))
    }

    private static func tier(_ x: Species, _ y: Species) -> KnowledgeTier { max(x.tier, y.tier) }
    private static func note(_ x: Species, _ y: Species) -> String? { x.note ?? y.note }

    /// 不稳定酸根：遇到比自身共轭酸更强的酸时，直接分解成「水 + 气体」跑掉
    struct UnstableAcidRoot {
        let conjugateAcid: String   // 用来比酸性强弱
        let gas: String             // 实际放出的气体
    }

    private static let unstableAcids: [String: UnstableAcidRoot] = [
        "CO3": UnstableAcidRoot(conjugateAcid: "H2CO3", gas: "CO2"),
        "HCO3": UnstableAcidRoot(conjugateAcid: "H2CO3", gas: "CO2"),
        "SO3": UnstableAcidRoot(conjugateAcid: "H2SO3", gas: "SO2")
    ]

    private static func precipitateColor(of formula: String, fallback: ColorHint = .white) -> ColorHint {
        ColorTable.precipitate[formula] ?? fallback
    }

    // MARK: - 复分解：酸 + 碱 → 盐 + 水

    static func acidBase(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isAcid, y.isBase, let anion = x.anion, let cation = y.cation else { return nil }
        guard let product = salt(cation, anion) else { return nil }

        var phenomena: [Phenomenon] = [.heat]
        if y.solubility != .soluble {
            phenomena.append(.solidDissolves)
            if let color = ColorTable.solutionColor(ofCation: cation) { phenomena.append(.solutionTurns(color)) }
        }
        return ReactionFactory.make(
            lhs: [ProductSpec(y.formula), ProductSpec(x.formula)],
            rhs: [product, ProductSpec("H2O", state: .liquid)],
            rule: "中和反应", phenomena: phenomena, tier: tier(x, y),
            note: note(x, y) ?? "酸 + 碱 → 盐 + 水，中和反应都放热"
        )
    }

    // MARK: - 酸 + 碱性氧化物 → 盐 + 水

    static func acidBasicOxide(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isAcid, y.isBasicOxide, let anion = x.anion, let cation = y.cation else { return nil }
        guard let product = salt(cation, anion) else { return nil }
        var phenomena: [Phenomenon] = [.solidDissolves]
        if let color = ColorTable.solutionColor(ofCation: cation) { phenomena.append(.solutionTurns(color)) }
        return ReactionFactory.make(
            lhs: [ProductSpec(y.formula), ProductSpec(x.formula)],
            rhs: [product, ProductSpec("H2O", state: .liquid)],
            rule: "碱性氧化物与酸", phenomena: phenomena, tier: tier(x, y),
            note: note(x, y) ?? "金属氧化物要先写成对应的金属离子，再与酸根结合成盐"
        )
    }

    // MARK: - 金属 + 非氧化性酸 → 盐 + 氢气

    static func metalAcid(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isMetal, y.isAcid, !y.oxidizingAcid,
              let symbol = x.elementSymbol, let anion = y.anion,
              ActivitySeries.reactsWithAcid(symbol) else { return nil }
        guard let ion = Valence.metalIon(symbol), let product = salt(ion, anion) else { return nil }

        var phenomena: [Phenomenon] = [.gas, .solidDissolves]
        if let color = ColorTable.solutionColor(ofCation: ion) { phenomena.append(.solutionTurns(color)) }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [product, ProductSpec("H2", state: .gas)],
            rule: "金属与酸置换", phenomena: phenomena, tier: tier(x, y),
            note: note(x, y) ?? "活动性排在氢之前的金属才能置换出酸中的氢"
        )
    }

    // MARK: - 金属 + 氧化性酸（硝酸 / 浓硫酸）→ 盐 + 水 + 氮/硫氧化物

    static func metalOxidizingAcid(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isMetal, y.oxidizingAcid, let symbol = x.elementSymbol, let anion = y.anion,
              let ion = Valence.metalIon(symbol) else { return nil }
        guard let product = salt(ion, anion) else { return nil }

        let isNitric = y.formula == "HNO3"
        let gas = isNitric ? "NO" : "SO2"
        let condition = isNitric ? "稀硝酸" : "浓硫酸、加热"
        var phenomena: [Phenomenon] = [.gas]
        if let color = ColorTable.solutionColor(ofCation: ion) { phenomena.append(.solutionTurns(color)) }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [product, ProductSpec(gas, state: .gas), ProductSpec("H2O", state: .liquid)],
            rule: "氧化性酸溶解金属", phenomena: phenomena, tier: .senior, condition: condition,
            note: "氧化性酸与金属反应生成水而不是氢气"
        )
    }

    // MARK: - 活泼金属 + 水 → 碱 + 氢气

    static func activeMetalWater(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isMetal, y.isWater, let symbol = x.elementSymbol,
              ActivitySeries.reactsWithWater(symbol), let ion = Valence.metalIon(symbol) else { return nil }
        guard let base = salt(ion, Ions.OH) else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec("H2O")],
            rhs: [base, ProductSpec("H2", state: .gas)],
            rule: "活泼金属与水", phenomena: [.gas, .heat, .colorChange("钠浮于水面、熔成小球、四处游动并发出嘶嘶声")],
            tier: tier(x, y),
            note: note(x, y) ?? "K、Ca、Na 太活泼，投入盐溶液时会先与水反应"
        )
    }

    // MARK: - 酸性氧化物 + 碱 → 盐 + 水

    static func acidicOxideBase(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isAcidicOxide, y.isBase, let anion = x.anion, let cation = y.cation else { return nil }
        guard let product = salt(cation, anion) else { return nil }
        var phenomena: [Phenomenon] = []
        if product.state == .solid {
            phenomena.append(.precipitate(precipitateColor(of: product.formula)))
        } else {
            phenomena.append(.noVisibleChange)
        }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [product, ProductSpec("H2O", state: .liquid)],
            rule: "酸性氧化物与碱", phenomena: phenomena, tier: tier(x, y),
            note: note(x, y) ?? "碱 + 非金属氧化物 → 盐 + 水（不属于复分解反应）"
        )
    }

    // MARK: - 酸性氧化物 + 水 → 酸

    static func acidicOxideWater(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isAcidicOxide, y.isWater, let anion = x.anion, !x.formula.hasPrefix("SiO2") else { return nil }
        guard let acid = salt(Ions.H, anion) else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec("H2O")],
            rhs: [acid],
            rule: "酸性氧化物与水", phenomena: [.heat], tier: tier(x, y),
            note: "多数非金属氧化物溶于水生成对应的酸，SiO2 不溶于水"
        )
    }

    // MARK: - 碱性氧化物 + 水 → 碱（仅可溶性强碱对应的氧化物）

    static func basicOxideWater(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isBasicOxide, y.isWater, let cation = x.cation else { return nil }
        let base = salt(cation, Ions.OH)
        guard let base, SolubilityTable.of(cation: cation, anion: Ions.OH) != .insoluble else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec("H2O")],
            rhs: [base],
            rule: "碱性氧化物与水", phenomena: [.heat], tier: tier(x, y),
            note: "只有 K、Na、Ca、Ba 的氧化物能与水化合生成可溶碱"
        )
    }

    // MARK: - 酸 + 盐 → 新酸 + 新盐

    static func acidSalt(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isAcid, y.isSalt, let acidAnion = x.anion,
              let saltCation = y.cation, let saltAnion = y.anion else { return nil }

        // 难溶盐一般不与酸反应，碳酸盐/亚硫酸盐例外（生成气体逸出）
        let gasForming: Set<String> = ["CO3", "HCO3", "SO3", "S"]
        if y.solubility == .insoluble, !gasForming.contains(saltAnion.symbol) { return nil }

        guard let newSalt = salt(saltCation, acidAnion) else { return nil }

        var products: [ProductSpec] = [newSalt]
        var phenomena: [Phenomenon] = []

        if let unstable = unstableAcids[saltAnion.symbol] {
            // 碳酸盐 / 亚硫酸盐 + 较强的酸 → 盐 + 水 + 酸性气体；硅酸这类更弱的酸赶不出 CO₂
            guard AcidStrength.stronger(x.formula, than: unstable.conjugateAcid) else { return nil }
            products.append(ProductSpec("H2O", state: .liquid))
            products.append(ProductSpec(unstable.gas, state: .gas))
            phenomena.append(.gas)
            if y.solubility != .soluble { phenomena.append(.solidDissolves) }
        } else if let newAcid = salt(Ions.H, saltAnion) {
            let makesWeakerAcid = AcidStrength.stronger(x.formula, than: newAcid.formula)
            // 生成不溶于强酸的沉淀时是例外：H₂S + CuSO₄ → CuS↓ + H₂SO₄
            let drivesInsolubleSalt = AcidStrength.acidInsolubleSalts.contains(newSalt.formula)
            guard makesWeakerAcid || drivesInsolubleSalt else { return nil }
            if newAcid.state == .solid {
                products.append(ProductSpec(newAcid.formula, state: .solid))
                phenomena.append(.precipitate(precipitateColor(of: newAcid.formula)))
            } else if newAcid.formula == "H2S" {
                products.append(ProductSpec("H2S", state: .gas))
                phenomena.append(.gas)
            } else {
                products.append(newAcid)
            }
        } else {
            return nil
        }

        if newSalt.state == .solid { phenomena.append(.precipitate(precipitateColor(of: newSalt.formula))) }
        if phenomena.isEmpty { phenomena.append(.noVisibleChange) }

        return ReactionFactory.make(
            lhs: [ProductSpec(y.formula), ProductSpec(x.formula)],
            rhs: products,
            rule: "盐与酸", phenomena: phenomena, tier: tier(x, y),
            note: note(x, y) ?? "复分解反应发生的条件：生成沉淀、气体或水"
        )
    }

    // MARK: - 碱 + 盐 → 新碱 + 新盐

    static func baseSalt(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isBase, y.isSalt, let baseCation = x.cation,
              let saltCation = y.cation, let saltAnion = y.anion else { return nil }
        // 反应物必须都可溶（碱要能电离）
        guard x.solubility == .soluble, y.solubility == .soluble else { return nil }

        if saltCation.symbol == "NH4" {
            // 铵盐 + 碱 → 盐 + 氨气 + 水
            guard let newSalt = salt(baseCation, saltAnion) else { return nil }
            return ReactionFactory.make(
                lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
                rhs: [newSalt, ProductSpec("NH3", state: .gas), ProductSpec("H2O", state: .liquid)],
                rule: "碱与铵盐", phenomena: [.gas, .colorChange("放出有刺激性气味、能使湿润红色石蕊试纸变蓝的气体")],
                tier: tier(x, y),
                note: "铵态氮肥不能与碱性肥料混用，否则肥效损失"
            )
        }

        guard let newBase = salt(saltCation, Ions.OH), let newSalt = salt(baseCation, saltAnion) else { return nil }
        guard newBase.state == .solid || newSalt.state == .solid else { return nil }

        var phenomena: [Phenomenon] = []
        if newBase.state == .solid { phenomena.append(.precipitate(precipitateColor(of: newBase.formula))) }
        if newSalt.state == .solid { phenomena.append(.precipitate(precipitateColor(of: newSalt.formula))) }

        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [newBase, newSalt],
            rule: "碱与盐", phenomena: phenomena, tier: tier(x, y),
            note: note(x, y) ?? "碱与盐反应要求两者都可溶，且生成物中有沉淀"
        )
    }

    // MARK: - 盐 + 盐 → 两种新盐

    static func saltSalt(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isSalt, y.isSalt,
              let cationX = x.cation, let anionX = x.anion,
              let cationY = y.cation, let anionY = y.anion else { return nil }
        guard x.solubility == .soluble, y.solubility == .soluble else { return nil }
        guard let left = salt(cationX, anionY), let right = salt(cationY, anionX) else { return nil }
        // 生成物中必须有沉淀，否则不反应（NaCl + KNO3 就是典型反例）
        guard left.state == .solid || right.state == .solid else { return nil }

        var products = [left, right]
        if left.state != .solid, right.state == .solid { products = [right, left] }

        var phenomena: [Phenomenon] = []
        if left.state == .solid { phenomena.append(.precipitate(precipitateColor(of: left.formula))) }
        if right.state == .solid { phenomena.append(.precipitate(precipitateColor(of: right.formula))) }

        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: products,
            rule: "盐与盐", phenomena: phenomena, tier: tier(x, y),
            note: "两种盐都须可溶，且交换成分后生成沉淀"
        )
    }

    // MARK: - 金属 + 盐溶液 → 新盐 + 新金属

    static func metalSalt(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isMetal, y.isSalt, let symbol = x.elementSymbol,
              let saltCation = y.cation, let saltAnion = y.anion else { return nil }
        guard y.solubility == .soluble else { return nil }
        guard !ActivitySeries.reactsWithWater(symbol) else { return nil }      // K/Ca/Na 先与水反应
        guard let myIon = Valence.metalIon(symbol),
              ActivitySeries.canDisplace(symbol, saltCation.symbol) else { return nil }
        guard let newSalt = salt(myIon, saltAnion) else { return nil }

        var phenomena: [Phenomenon] = [.colorChange("\(symbol)表面覆盖一层\(ColorTable.metalColor(saltCation.symbol).rawValue)金属")]
        if let from = ColorTable.solutionColor(ofCation: saltCation), let to = ColorTable.solutionColor(ofCation: myIon) {
            phenomena.append(.colorChange("溶液由\(from.rawValue)变为\(to.rawValue)"))
        }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [newSalt, ProductSpec(saltCation.symbol, state: .solid)],
            rule: "金属与盐置换", phenomena: phenomena, tier: tier(x, y),
            note: note(x, y) ?? "活动性强的金属能把活动性弱的金属从其盐溶液中置换出来"
        )
    }

    // MARK: - 酸式盐 + 碱 → 正盐 + 水

    static func acidSaltWithBase(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isSalt, y.isBase, let anion = x.anion, let cation = x.cation,
              let baseCation = y.cation, anion.symbol == "HCO3" else { return nil }
        // HCO3⁻ + OH⁻ → CO3²⁻ + H2O，再与金属阳离子结合
        let merged = salt(cation, Ions.CO3)
        let paired = salt(baseCation, Ions.CO3)
        let product = merged ?? paired
        guard let product else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [product, ProductSpec("H2O", state: .liquid)],
            rule: "酸式盐与碱", phenomena: product.state == .solid
                ? [.precipitate(precipitateColor(of: product.formula))] : [.noVisibleChange],
            tier: .senior,
            note: "NaHCO3 + NaOH → Na2CO3 + H2O，小苏打受热或遇碱都会转化"
        )
    }

    // MARK: - 两性氢氧化物 / 两性氧化物 + 强碱 → 偏铝酸盐 + 水

    static func amphotericWithBase(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isAmphoteric, y.isBase, y.strongBase, let baseCation = y.cation else { return nil }
        guard x.formula.hasPrefix("Al") else { return nil }
        guard let aluminate = salt(baseCation, Ions.AlO2) else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [aluminate, ProductSpec("H2O", state: .liquid)],
            rule: "两性物质与强碱", phenomena: [.solidDissolves], tier: .senior,
            note: "Al(OH)₃、Al₂O₃ 既能溶于酸又能溶于强碱"
        )
    }

    // MARK: - 酸性氧化物 + 碱性氧化物 → 含氧酸盐

    static func acidicWithBasicOxide(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isAcidicOxide, y.isBasicOxide, let anion = x.anion, let cation = y.cation else { return nil }
        guard let product = salt(cation, anion) else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [product],
            rule: "酸性氧化物与碱性氧化物", phenomena: [.noVisibleChange],
            tier: .senior, condition: "高温",
            note: "SiO₂ + CaO —高温→ CaSiO₃，高炉炼铁除脉石就是这个反应"
        )
    }

    // MARK: - 金属 + 氧气 → 金属氧化物

    static func metalOxygen(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isMetal, y.formula == "O2", let symbol = x.elementSymbol else { return nil }
        let oxideID: String
        switch symbol {
        case "Fe": oxideID = "fe3o4"      // 铁在氧气中燃烧生成四氧化三铁
        case "Na": oxideID = "na2o"
        case "Ca": oxideID = "cao"
        case "Mg": oxideID = "mgo"
        case "Cu": oxideID = "cuo"
        case "K": oxideID = "k2o"
        case "Al": oxideID = "al2o3"
        default: return nil
        }
        guard let oxide = Chemistry.species(oxideID) else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec("O2")],
            rhs: [ProductSpec(oxide.formula, state: .solid)],
            rule: "金属燃烧", phenomena: [.flame(symbol == "Mg" ? .white : .yellow), .heat],
            tier: tier(x, y), condition: "点燃",
            note: note(x, y) ?? "铁在纯氧中燃烧生成 Fe₃O₄ 而不是 Fe₂O₃"
        )
    }

    // MARK: - 非金属 + 氧气 → 非金属氧化物

    static func nonmetalOxygen(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isNonmetal, y.formula == "O2" else { return nil }
        let productID: String
        switch x.formula {
        case "C": productID = "co2"
        case "S": productID = "so2"
        case "P": productID = "p2o5"
        case "H2": productID = "h2o"
        default: return nil
        }
        guard let oxide = Chemistry.species(productID) else { return nil }
        var phenomena: [Phenomenon] = [.flame(x.formula == "S" ? .blue : .white), .heat]
        if oxide.isAcidicOxide { phenomena.append(.gas) }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec("O2")],
            rhs: [ProductSpec(oxide.formula, state: oxide.isWater ? .liquid : .gas)],
            rule: "非金属燃烧", phenomena: phenomena, tier: tier(x, y), condition: "点燃",
            note: note(x, y) ?? (x.formula == "C" ? "氧气不足时会生成 CO，注意配给" : nil)
        )
    }

    // MARK: - 有机物燃烧

    static func organicCombustion(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isOrganic, y.formula == "O2" else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec("O2")],
            rhs: [ProductSpec("CO2", state: .gas), ProductSpec("H2O", state: .liquid)],
            rule: "有机物燃烧", phenomena: [.flame(.blue), .gas, .heat],
            tier: .senior, condition: "点燃",
            note: note(x, y) ?? "含碳氢的有机物完全燃烧生成 CO₂ 和 H₂O"
        )
    }

    // MARK: - 还原剂（H₂ / CO / C）还原金属氧化物

    static func reductionByGasOrCarbon(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isReducing, y.isBasicOxide, let cation = y.cation else { return nil }
        guard ["H2", "CO", "C"].contains(x.formula) else { return nil }
        // 只有 Zn 及之后活动的金属氧化物才能被 H₂ / CO / C 还原
        guard let metalRank = ActivitySeries.rank(cation.symbol),
              let zincRank = ActivitySeries.rank("Zn"), metalRank >= zincRank else { return nil }
        let metal = cation.symbol
        let byproduct = x.formula == "H2" ? "H2O" : "CO2"
        let condition = x.formula == "H2" ? "加热" : "高温"
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [ProductSpec(metal, state: .solid), ProductSpec(byproduct, state: .gas)],
            rule: "还原剂还原金属氧化物",
            phenomena: [.colorChange("黑色固体逐渐变为红色"), .gas],
            tier: y.formula.hasPrefix("Fe") ? .senior : .junior, condition: condition,
            note: note(x, y) ?? "CO 还原氧化铁是高炉炼铁的原理；CO 有毒，尾气要点燃或收集"
        )
    }

    // MARK: - 金属 + 卤素 / 硫 → 无氧酸盐

    static func metalWithNonmetal(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isMetal, y.isNonmetal, let symbol = x.elementSymbol else { return nil }
        let anion: Ion
        switch y.formula {
        case "Cl2": anion = Ions.Cl
        case "S": anion = Ions.S
        default: return nil
        }
        guard let ion = Valence.metalIon(symbol, strongOxidizer: y.formula == "Cl2") else { return nil }
        guard let product = salt(ion, anion) else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [product],
            rule: "金属与卤素/硫", phenomena: [.heat, .gas],
            tier: .senior, condition: "点燃",
            note: "氯气把铁氧化到 +3（FeCl₃），硫只能到 +2（FeS）"
        )
    }

    // MARK: - 卤素置换：活动性 Cl₂ > Br₂ > I₂

    static func halogenDisplacement(_ x: Species, _ y: Species) -> Reaction? {
        guard x.isNonmetal, y.isSalt, let saltCation = y.cation, let saltAnion = y.anion else { return nil }
        let order = ["Cl": 0, "Br": 1, "I": 2]
        guard let freeElement = x.elementSymbol, x.formula.hasSuffix("2"),
              let me = order[freeElement], let other = order[saltAnion.symbol], me < other,
              let myIon = halideIon(freeElement) else { return nil }
        guard let newSalt = salt(saltCation, myIon),
              let released = Valence.halogenMolecule(other) else { return nil }
        return ReactionFactory.make(
            lhs: [ProductSpec(x.formula), ProductSpec(y.formula)],
            rhs: [newSalt, ProductSpec(released, state: other == 1 ? .liquid : .solid)],
            rule: "卤素置换", phenomena: [.colorChange("溶液颜色加深，有卤素单质生成")],
            tier: .senior,
            note: "卤素活动性 Cl₂ > Br₂ > I₂，前者能把后者从其盐溶液中置换出来"
        )
    }

    private static func halideIon(_ symbol: String) -> Ion? {
        switch symbol {
        case "Cl": return Ions.Cl
        case "Br": return Ions.Br
        case "I": return Ions.I
        default: return nil
        }
    }
}

import XCTest
@testable import ChemCards

final class ReactionEngineTests: XCTestCase {

    /// 运行期裁判是这张落盘的表，测试必须测它本身，而不是推导兜底
    static let shippedTable = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()        // Tests/ChemCardsTests
        .deletingLastPathComponent()        // Tests
        .deletingLastPathComponent()        // 仓库根
        .appendingPathComponent("Resources/Data/reactions.json")

    override class func setUp() {
        super.setUp()
        do {
            _ = try ReactionTable.load(url: shippedTable)
        } catch {
            XCTFail("无法读取 \(shippedTable.path)：\(error)。生成命令：swift run ChemCards --dump-reactions")
        }
    }

    private func sp(_ id: String) -> Species {
        guard let species = Chemistry.species(id) else {
            XCTFail("未知物种 \(id)")
            return Species(id: id, formula: id, name: id, category: .function)
        }
        return species
    }

    private func reaction(_ a: String, _ b: String) -> Reaction? { ReactionEngine.resolve(sp(a), sp(b)) }
    private func equation(_ a: String, _ b: String) -> String? { reaction(a, b)?.displayEquation }

    // MARK: 经典必发反应

    func testClassicReactions() {
        XCTAssertEqual(equation("naoh", "hcl"), "NaOH + HCl → NaCl + H₂O")
        XCTAssertEqual(equation("h2so4", "naoh"), "2NaOH + H₂SO₄ → Na₂SO₄ + 2H₂O")
        XCTAssertEqual(equation("fe", "hcl"), "Fe + 2HCl → FeCl₂ + H₂↑")
        XCTAssertEqual(equation("zn", "h2so4"), "Zn + H₂SO₄ → ZnSO₄ + H₂↑")
        XCTAssertEqual(equation("caco3", "hcl"), "CaCO₃ + 2HCl → CaCl₂ + H₂O + CO₂↑")
        XCTAssertEqual(equation("na2co3", "hcl"), "Na₂CO₃ + 2HCl → 2NaCl + H₂O + CO₂↑")
        XCTAssertEqual(equation("naoh", "co2"), "CO₂ + 2NaOH → Na₂CO₃ + H₂O")
        XCTAssertEqual(equation("caoh2", "co2"), "CO₂ + Ca(OH)₂ → CaCO₃↓ + H₂O")
        XCTAssertEqual(equation("cuo", "h2so4"), "CuO + H₂SO₄ → CuSO₄ + H₂O")
        XCTAssertEqual(equation("fe2o3", "hcl"), "Fe₂O₃ + 6HCl → 2FeCl₃ + 3H₂O")
        XCTAssertEqual(equation("fe", "cuso4"), "Fe + CuSO₄ → FeSO₄ + Cu")
        XCTAssertEqual(equation("cu", "agno3"), "Cu + 2AgNO₃ → Cu(NO₃)₂ + 2Ag")
        XCTAssertEqual(equation("nacl", "agno3"), "NaCl + AgNO₃ → AgCl↓ + NaNO₃")
        XCTAssertEqual(equation("bacl2", "na2so4"), "BaCl₂ + Na₂SO₄ → BaSO₄↓ + 2NaCl")
        XCTAssertEqual(equation("naoh", "cuso4"), "2NaOH + CuSO₄ → Cu(OH)₂↓ + Na₂SO₄")
        XCTAssertEqual(equation("cao", "h2o"), "CaO + H₂O → Ca(OH)₂")
        XCTAssertEqual(equation("na2o", "h2o"), "Na₂O + H₂O → 2NaOH")
        XCTAssertEqual(equation("co2", "h2o"), "CO₂ + H₂O → H₂CO₃")
        XCTAssertEqual(equation("mg", "o2"), "2Mg + O₂ —点燃→ 2MgO")
        XCTAssertEqual(equation("h2", "o2"), "2H₂ + O₂ —点燃→ 2H₂O")
        XCTAssertEqual(equation("h2", "cuo"), "H₂ + CuO —加热→ Cu + H₂O")
        XCTAssertEqual(equation("co", "fe2o3"), "3CO + Fe₂O₃ —高温→ 2Fe + 3CO₂")
        XCTAssertEqual(equation("nahco3", "hcl"), "NaHCO₃ + HCl → NaCl + H₂O + CO₂↑")
        XCTAssertEqual(equation("nh4cl", "naoh"), "NaOH + NH₄Cl → NaCl + NH₃↑ + H₂O")
    }

    func testHighSchoolReactions() {
        XCTAssertEqual(equation("cu", "h2so4_conc"), "Cu + 2H₂SO₄ —浓硫酸、加热→ CuSO₄ + SO₂↑ + 2H₂O")
        XCTAssertEqual(equation("ag", "hno3"), "3Ag + 4HNO₃ —稀硝酸→ 3AgNO₃ + NO↑ + 2H₂O")
        XCTAssertEqual(equation("al", "fe2o3"), "2Al + Fe₂O₃ —高温、镁条引燃→ Al₂O₃ + 2Fe")
        XCTAssertEqual(equation("cl2", "kbr"), "Cl₂ + 2KBr → 2KCl + Br₂")
        XCTAssertEqual(equation("fe", "cl2"), "2Fe + 3Cl₂ —点燃→ 2FeCl₃")
        XCTAssertEqual(equation("fe", "s"), "Fe + S —点燃→ FeS")
        XCTAssertEqual(equation("aloh3", "naoh"), "Al(OH)₃ + NaOH → NaAlO₂ + 2H₂O")
        XCTAssertEqual(equation("sio2", "naoh"), "SiO₂ + 2NaOH → Na₂SiO₃ + H₂O")
        XCTAssertEqual(equation("h2s", "so2"), "2H₂S + SO₂ → 3S↓ + 2H₂O")
        XCTAssertEqual(equation("cu", "s"), "2Cu + S —加热→ Cu₂S", "硫只能把铜氧化到 +1")
        XCTAssertEqual(equation("hno3", "na2so3"), "2HNO₃ + 3Na₂SO₃ → 3Na₂SO₄ + 2NO + H₂O")
        XCTAssertTrue(ReactionEngine.explain(top: sp("hno3"), candidate: sp("kbr")).contains("氧化还原"))
    }

    // MARK: 必须不反应的经典反例

    func testKnownNonReactions() {
        XCTAssertNil(reaction("cu", "hcl"), "铜不能置换稀盐酸中的氢")
        XCTAssertNil(reaction("ag", "h2so4"), "银不与稀硫酸反应")
        XCTAssertNil(reaction("nacl", "kno3"), "NaCl 与 KNO₃ 交换成分后全无沉淀")
        XCTAssertNil(reaction("baso4", "hcl"), "硫酸钡既不溶于水也不溶于酸")
        XCTAssertNil(reaction("cu", "feso4"), "铜不能置换铁")
        XCTAssertNil(reaction("naoh", "kno3"), "无沉淀无气体无水，不反应")
        XCTAssertNil(reaction("fe", "h2so4_conc"), "常温下铁遇浓硫酸钝化")
        XCTAssertNil(reaction("al", "hno3"), "常温下铝遇硝酸钝化")
        XCTAssertNil(reaction("co2", "co"), "同种元素相邻价态不归中")
        XCTAssertNil(reaction("h2o", "o2"), "水与氧气不反应")
        XCTAssertNil(reaction("caco3", "na2so4"), "碳酸钙难溶，不能与硫酸钠发生盐盐反应")
        XCTAssertNil(reaction("cuoh2", "na2co3"), "难溶碱不能与盐反应")
        XCTAssertNil(reaction("h2sio3", "caco3"), "硅酸比碳酸还弱，赶不出 CO₂")
        XCTAssertNil(reaction("h2co3", "bacl2"), "碳酸制不出 BaCO₃ 沉淀的同时还放出盐酸")
        XCTAssertNil(reaction("na2so4", "agno3"), "Ag₂SO₄ 微溶，不算沉淀，不驱动复分解")
        XCTAssertNil(reaction("hno3", "kbr"), "硝酸氧化 Br⁻，不按复分解生成 HBr")
        XCTAssertNil(reaction("h2so4_conc", "na2so3"), "浓硫酸会氧化亚硫酸根，制不出 SO₂")
    }

    // MARK: 对称性：能否反应与顺序无关

    func testSymmetryOverAllPairs() {
        let species = Chemistry.all
        var checked = 0
        for i in 0..<species.count {
            for j in (i + 1)..<species.count {
                let a = species[i], b = species[j]
                let forward = ReactionEngine.resolve(a, b) != nil
                let backward = ReactionEngine.resolve(b, a) != nil
                XCTAssertEqual(forward, backward, "\(a.name) 与 \(b.name) 的判定不对称")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 2000)
    }

    // MARK: 表与推导不漂移

    func testShippedTableMatchesGenerator() {
        let shipped = (try? ReactionTable.load(url: Self.shippedTable)) ?? [:]
        let generated = ReactionTable.generated()
        let missing = Set(generated.keys).subtracting(shipped.keys).sorted().prefix(5).joined(separator: ", ")
        let extra = Set(shipped.keys).subtracting(generated.keys).sorted().prefix(5).joined(separator: ", ")
        XCTAssertEqual(Set(shipped.keys), Set(generated.keys), """
        反应表与规则推导结果不一致，请重新生成：
        swift run ChemCards --dump-reactions Resources/Data/reactions.json
        缺失示例：\(missing)
        多余示例：\(extra)
        """)
        for (pair, reaction) in generated {
            XCTAssertEqual(shipped[pair]?.displayEquation, reaction.displayEquation, "\(pair) 的方程式与推导结果不同")
        }
    }

    func testTableKeysPointAtTheirOwnSpecies() {
        let shipped = (try? ReactionTable.load(url: Self.shippedTable)) ?? [:]
        for (pair, reaction) in shipped {
            let ids = pair.split(separator: "+").map(String.init)
            XCTAssertEqual(ids.count, 2, "键格式应为 a+b，实际 \(pair)")
            guard let a = Chemistry.species(ids[0]), let b = Chemistry.species(ids[1]) else {
                return XCTFail("表里引用了未登记的物种：\(pair)")
            }
            XCTAssertEqual(ReactionTable.key(a, b), pair, "\(pair) 没有按登记表顺序规范化")
            XCTAssertEqual(ReactionTable.reaction(a, b)?.displayEquation, reaction.displayEquation, "\(pair) 查不到自己的记录")
            XCTAssertEqual(ReactionTable.reaction(b, a)?.displayEquation, reaction.displayEquation, "\(pair) 反序查不到")
            let lhs = reaction.equation.lhs.map(\.formula)
            XCTAssertTrue(lhs.contains(a.formula) && lhs.contains(b.formula),
                          "\(pair) 的方程式反应物对不上：\(reaction.displayEquation)")
        }
    }

    // MARK: 全表守恒：任何一条引擎给出的方程式都必须配平

    func testEveryReactionIsAtomBalanced() {
        let reactions = ReactionEngine.allReactions()
        XCTAssertGreaterThan(reactions.count, 400, "引擎应能推出数百条反应")
        for reaction in reactions {
            XCTAssertTrue(reaction.equation.isAtomBalanced(),
                          "未配平: \(reaction.displayEquation)（差集 \(reaction.equation.unbalancedElements)）")
            XCTAssertFalse(reaction.equation.lhs.isEmpty)
            XCTAssertFalse(reaction.equation.rhs.isEmpty)
        }
    }

    func testEveryCuratedEntryResolves() {
        for entry in CuratedReactions.table {
            guard let a = Chemistry.species(entry.a), let b = Chemistry.species(entry.b) else {
                return XCTFail("精选反应引用了不存在的物种 \(entry.a)/\(entry.b)")
            }
            XCTAssertNotNil(ReactionEngine.resolve(a, b), "精选反应无法配平: \(a.name) + \(b.name) → \(entry.products)")
        }
    }

    func testRulesCoverExpectedCount() {
        // 每条规则都应至少命中一次，否则是死代码
        let species = Chemistry.all
        for rule in ReactionRules.all {
            var hit = false
            outer: for a in species {
                for b in species where a.id != b.id {
                    if BlockedReactions.reason(a, b) == nil, rule.apply(a, b) != nil { hit = true; break outer }
                }
            }
            XCTAssertTrue(hit, "规则「\(rule.name)」从未命中，请检查条件或补物种")
        }
    }

    // MARK: 现象与得分

    func testPhenomenaAndPoints() {
        let neutral = reaction("naoh", "hcl")
        XCTAssertEqual(neutral?.rule, "中和反应")
        XCTAssertTrue(neutral?.phenomena.contains(.heat) ?? false)
        XCTAssertGreaterThan(neutral?.points ?? 0, Reaction.basePoints)

        let precipitate = reaction("naoh", "cuso4")
        XCTAssertTrue(precipitate?.phenomena.contains(.precipitate(.blue)) ?? false)

        let senior = reaction("al", "fe2o3")
        XCTAssertEqual(senior?.tier, .senior)
        XCTAssertGreaterThan(senior?.points ?? 0, neutral?.points ?? 0, "高中反应应比初中反应得分更高")
    }

    func testExplainGivesTeachingReason() {
        XCTAssertTrue(ReactionEngine.explain(top: sp("hcl"), candidate: sp("cu")).contains("氢"))
        XCTAssertTrue(ReactionEngine.explain(top: sp("h2so4_conc"), candidate: sp("fe")).contains("钝化"))
        XCTAssertTrue(ReactionEngine.explain(top: sp("nacl"), candidate: sp("kno3")).contains("沉淀"))
    }
}

import XCTest
@testable import ChemCards

/// 物种登记表的一致性自检：手写化学式必须能被「电荷交叉约简」推导出来，
/// 溶解性/活动性判定也必须与表一致。新增物质时这里是第一道防线。
final class ChemistryRegistryTests: XCTestCase {

    func testRegistryIsPopulated() {
        XCTAssertGreaterThan(Chemistry.all.count, 60)
        XCTAssertEqual(Chemistry.all.count, Set(Chemistry.all.map(\.id)).count, "物种 id 重复")
    }

    func testEveryFormulaParses() {
        for species in Chemistry.all {
            XCTAssertNotNil(FormulaKit.parse(species.formula), "\(species.id) 化学式无法解析: \(species.formula)")
        }
    }

    func testIonicFormulasMatchCrossReduction() {
        // 酸的化学式按书写习惯排列（CH3COOH、NH3·H2O），无法由交叉约简直接得到，单独放行
        let whitelisted: Set<String> = ["acoh", "nh3h2o"]
        for species in Chemistry.all {
            guard let cation = species.cation, let anion = species.anion, !whitelisted.contains(species.id) else { continue }
            let derived = FormulaKit.compound(fromCation: cation, anion: anion)?.formula
            XCTAssertEqual(derived, species.formula, "\(species.id) 的化学式与交叉约简结果不一致")
        }
    }

    func testCategoryAndRoleAgree() {
        for species in Chemistry.all {
            switch species.category {
            case .acid: XCTAssertTrue(species.isAcid, "\(species.id) 归类为酸但 role 不是 acid")
            case .base: XCTAssertTrue(species.isBase, "\(species.id) 归类为碱但 role 不是 base")
            case .salt: XCTAssertTrue(species.isSalt, "\(species.id) 归类为盐但 role 不是 salt")
            case .metal: XCTAssertTrue(species.isMetal)
            case .nonmetal: XCTAssertTrue(species.isNonmetal)
            case .organic: XCTAssertTrue(species.isOrganic)
            case .metalOxide: XCTAssertTrue(species.isOxide, "\(species.id) 应是氧化物")
            case .nonmetalOxide: XCTAssertTrue(species.isOxide || species.isWater, "\(species.id) 应是氧化物或水")
            case .function: break
            }
        }
    }

    func testMetalsHaveActivityRank() {
        for species in Chemistry.all where species.category == .metal {
            XCTAssertNotNil(species.elementSymbol, "\(species.id) 缺少元素符号")
            XCTAssertNotNil(species.activityRank, "\(species.id) 不在金属活动性顺序表中")
        }
    }

    func testAcidsAndBasesHaveIons() {
        for species in Chemistry.all {
            if species.isAcid {
                XCTAssertEqual(species.cation?.symbol, "H", "\(species.id) 酸的阳离子应为 H⁺")
                XCTAssertNotNil(species.anion, "\(species.id) 酸缺少酸根")
            }
            if species.isBase {
                XCTAssertEqual(species.anion?.symbol, "OH", "\(species.id) 碱的阴离子应为 OH⁻")
                XCTAssertNotNil(species.cation, "\(species.id) 碱缺少阳离子")
            }
            if species.isSalt {
                XCTAssertNotNil(species.cation, "\(species.id) 盐缺少阳离子")
                XCTAssertNotNil(species.anion, "\(species.id) 盐缺少阴离子")
            }
        }
    }

    // MARK: 溶解性表

    func testSolubilityRules() {
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Na", anionSymbol: "Cl"), .soluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "K", anionSymbol: "NO3"), .soluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "NH4", anionSymbol: "OH"), .soluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Ba", anionSymbol: "SO4"), .insoluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Ag", anionSymbol: "Cl"), .insoluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Ag", anionSymbol: "Br"), .insoluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Ca", anionSymbol: "CO3"), .insoluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Cu", anionSymbol: "OH"), .insoluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Fe", anionSymbol: "OH"), .insoluble)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Ca", anionSymbol: "OH"), .slight)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Ca", anionSymbol: "SO4"), .slight)
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "H", anionSymbol: "CO3"), .soluble, "碳酸应可溶")
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "H", anionSymbol: "SiO3"), .insoluble, "硅酸应难溶")
        XCTAssertEqual(SolubilityTable.of(cationSymbol: "Na", anionSymbol: "SiO3"), .soluble)
    }

    func testDeclaredSpeciesSolubility() {
        XCTAssertEqual(Chemistry.species("caco3")?.solubility, .insoluble)
        XCTAssertEqual(Chemistry.species("na2co3")?.solubility, .soluble)
        XCTAssertEqual(Chemistry.species("baso4")?.solubility, .insoluble)
        XCTAssertEqual(Chemistry.species("cuoh2")?.solubility, .insoluble)
        XCTAssertEqual(Chemistry.species("naoh")?.solubility, .soluble)
        XCTAssertEqual(Chemistry.species("kno3")?.solubility, .soluble)
    }

    // MARK: 金属活动性

    func testActivitySeries() {
        XCTAssertTrue(ActivitySeries.canDisplace("Fe", "Cu"))
        XCTAssertFalse(ActivitySeries.canDisplace("Cu", "Fe"))
        XCTAssertTrue(ActivitySeries.canDisplace("Zn", "H"))
        XCTAssertFalse(ActivitySeries.canDisplace("Ag", "H"))
        XCTAssertTrue(ActivitySeries.reactsWithAcid("Mg"))
        XCTAssertFalse(ActivitySeries.reactsWithAcid("Hg"))
        XCTAssertTrue(ActivitySeries.reactsWithWater("Na"))
        XCTAssertTrue(ActivitySeries.reactsWithWater("Ca"))
        XCTAssertFalse(ActivitySeries.reactsWithWater("Mg"), "镁与冷水反应极慢，不算活泼金属")
        XCTAssertEqual(ActivitySeries.rank("K"), 0)
        XCTAssertNil(ActivitySeries.rank("Xx"))
    }

    func testKeySpeciesExist() {
        for id in ["hcl", "h2so4", "naoh", "caco3", "cuso4", "fe", "cu", "o2", "co2", "cao", "h2o", "cuo"] {
            XCTAssertNotNil(Chemistry.species(id), "缺少关键物种 \(id)")
        }
        XCTAssertEqual(Chemistry.species("h2so4")?.oxidizingAcid, false)
        XCTAssertEqual(Chemistry.species("h2so4_conc")?.oxidizingAcid, true)
        XCTAssertEqual(Chemistry.species("hno3")?.oxidizingAcid, true)
    }

    func testDisplayNameFallback() {
        XCTAssertEqual(Chemistry.displayName(forFormula: "CaCO3"), "碳酸钙")
        XCTAssertEqual(Chemistry.displayName(forFormula: "Ca3(PO4)2"), "Ca3(PO4)2")
    }
}

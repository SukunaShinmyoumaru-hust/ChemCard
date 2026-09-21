import XCTest
@testable import ChemCards

final class FormulaKitTests: XCTestCase {

    // MARK: 解析

    func testParseSimple() {
        XCTAssertEqual(FormulaKit.parse("H2O"), ["H": 2, "O": 1])
        XCTAssertEqual(FormulaKit.parse("H2SO4"), ["H": 2, "S": 1, "O": 4])
        XCTAssertEqual(FormulaKit.parse("NaCl"), ["Na": 1, "Cl": 1])
        XCTAssertEqual(FormulaKit.parse("Fe2O3"), ["Fe": 2, "O": 3])
        XCTAssertEqual(FormulaKit.parse("Cl2"), ["Cl": 2])
        XCTAssertEqual(FormulaKit.parse("CaCO3"), ["Ca": 1, "C": 1, "O": 3])
    }

    func testParseNestedParentheses() {
        XCTAssertEqual(FormulaKit.parse("Ca(OH)2"), ["Ca": 1, "O": 2, "H": 2])
        XCTAssertEqual(FormulaKit.parse("Fe2(SO4)3"), ["Fe": 2, "S": 3, "O": 12])
        XCTAssertEqual(FormulaKit.parse("Al(OH)3"), ["Al": 1, "O": 3, "H": 3])
        XCTAssertEqual(FormulaKit.parse("(NH4)2SO4"), ["N": 2, "H": 8, "S": 1, "O": 4])
        XCTAssertEqual(FormulaKit.parse("Ca3(PO4)2"), ["Ca": 3, "P": 2, "O": 8])
    }

    func testParseAdducts() {
        // 胆矾 CuSO4·5H2O
        XCTAssertEqual(FormulaKit.parse("CuSO4·5H2O"), ["Cu": 1, "S": 1, "O": 9, "H": 10])
        XCTAssertEqual(FormulaKit.parse("NH3·H2O"), ["N": 1, "H": 5, "O": 1])
        XCTAssertEqual(FormulaKit.parse("CuSO4.5H2O"), FormulaKit.parse("CuSO4·5H2O"))
    }

    func testParseOrganic() {
        XCTAssertEqual(FormulaKit.parse("C2H5OH"), ["C": 2, "H": 6, "O": 1])
        XCTAssertEqual(FormulaKit.parse("CH3COOH"), ["C": 2, "H": 4, "O": 2])
        XCTAssertEqual(FormulaKit.parse("C6H12O6"), ["C": 6, "H": 12, "O": 6])
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(FormulaKit.parse(""))
        XCTAssertNil(FormulaKit.parse("2"))
        XCTAssertNil(FormulaKit.parse("Ca)OH("))
        XCTAssertNil(FormulaKit.parse("H2O!"))
        XCTAssertNil(FormulaKit.parse("()"))
    }

    // MARK: 渲染

    func testSubscripted() {
        XCTAssertEqual(FormulaKit.subscripted("H2SO4"), "H₂SO₄")
        XCTAssertEqual(FormulaKit.subscripted("Ca(OH)2"), "Ca(OH)₂")
        XCTAssertEqual(FormulaKit.subscripted("NaCl"), "NaCl")
    }

    func testChargeSuperscript() {
        XCTAssertEqual(FormulaKit.superscriptCharge(1), "⁺")
        XCTAssertEqual(FormulaKit.superscriptCharge(2), "²⁺")
        XCTAssertEqual(FormulaKit.superscriptCharge(3), "³⁺")
        XCTAssertEqual(FormulaKit.superscriptCharge(-1), "⁻")
        XCTAssertEqual(FormulaKit.superscriptCharge(-2), "²⁻")
        XCTAssertEqual(FormulaKit.superscriptCharge(0), "")
        XCTAssertEqual(Ion(symbol: "SO4", charge: -2).display, "SO₄²⁻")
        XCTAssertEqual(Ion(symbol: "OH", charge: -1).display, "OH⁻")
        XCTAssertEqual(Ion(symbol: "Fe", charge: 3).display, "Fe³⁺")
    }

    // MARK: 交叉约简

    func testCompoundFormulas() {
        func formula(_ c: Ion, _ a: Ion) -> String? { FormulaKit.compound(fromCation: c, anion: a)?.formula }

        XCTAssertEqual(formula(Ion(symbol: "Na", charge: 1), Ion(symbol: "Cl", charge: -1)), "NaCl")
        XCTAssertEqual(formula(Ion(symbol: "Ca", charge: 2), Ion(symbol: "Cl", charge: -1)), "CaCl2")
        XCTAssertEqual(formula(Ion(symbol: "Na", charge: 1), Ion(symbol: "SO4", charge: -2)), "Na2SO4")
        XCTAssertEqual(formula(Ion(symbol: "Fe", charge: 3), Ion(symbol: "SO4", charge: -2)), "Fe2(SO4)3")
        XCTAssertEqual(formula(Ion(symbol: "Ca", charge: 2), Ion(symbol: "OH", charge: -1)), "Ca(OH)2")
        XCTAssertEqual(formula(Ion(symbol: "Ca", charge: 2), Ion(symbol: "NO3", charge: -1)), "Ca(NO3)2")
        XCTAssertEqual(formula(Ion(symbol: "Al", charge: 3), Ion(symbol: "OH", charge: -1)), "Al(OH)3")
        XCTAssertEqual(formula(Ion(symbol: "NH4", charge: 1), Ion(symbol: "SO4", charge: -2)), "(NH4)2SO4")
        XCTAssertEqual(formula(Ion(symbol: "Ba", charge: 2), Ion(symbol: "OH", charge: -1)), "Ba(OH)2")
        XCTAssertEqual(formula(Ion(symbol: "H", charge: 1), Ion(symbol: "SO4", charge: -2)), "H2SO4")
        XCTAssertEqual(formula(Ion(symbol: "Cu", charge: 2), Ion(symbol: "NO3", charge: -1)), "Cu(NO3)2")
        XCTAssertEqual(formula(Ion(symbol: "Ag", charge: 1), Ion(symbol: "CO3", charge: -2)), "Ag2CO3")
        XCTAssertNil(formula(Ion(symbol: "Na", charge: 1), Ion(symbol: "K", charge: 1)))
    }

    func testCompoundFormulaIsAtomConsistent() {
        // 生成的化学式必须电荷守恒：交叉约简后阴阳离子总电荷相等
        let cations = [Ion(symbol: "Na", charge: 1), Ion(symbol: "Ca", charge: 2), Ion(symbol: "Fe", charge: 3),
                       Ion(symbol: "Al", charge: 3), Ion(symbol: "Cu", charge: 2), Ion(symbol: "NH4", charge: 1),
                       Ion(symbol: "Ba", charge: 2), Ion(symbol: "Ag", charge: 1), Ion(symbol: "Mg", charge: 2),
                       Ion(symbol: "Fe", charge: 2), Ion(symbol: "K", charge: 1), Ion(symbol: "Zn", charge: 2)]
        let anions = [Ion(symbol: "Cl", charge: -1), Ion(symbol: "SO4", charge: -2), Ion(symbol: "NO3", charge: -1),
                      Ion(symbol: "OH", charge: -1), Ion(symbol: "CO3", charge: -2), Ion(symbol: "S", charge: -2),
                      Ion(symbol: "SiO3", charge: -2), Ion(symbol: "AlO2", charge: -1), Ion(symbol: "PO4", charge: -3)]
        for c in cations {
            for a in anions {
                guard let r = FormulaKit.compound(fromCation: c, anion: a) else {
                    return XCTFail("无法组合 \(c.symbol) 与 \(a.symbol)")
                }
                XCTAssertNotNil(FormulaKit.parse(r.formula), "\(r.formula) 应可解析")
                XCTAssertEqual(r.cationCount * c.magnitude, r.anionCount * a.magnitude,
                               "\(r.formula) 电荷不守恒")
            }
        }
    }

    // MARK: 方程式守恒

    func testBalancedEquations() {
        let water = Equation(
            [EquationTerm(2, "H2", state: .gas), EquationTerm(1, "O2", state: .gas)],
            [EquationTerm(2, "H2O", state: .liquid)], condition: "点燃")
        XCTAssertTrue(water.isAtomBalanced(), water.unbalancedElements.description)

        let neutralization = Equation(
            [EquationTerm(1, "H2SO4"), EquationTerm(2, "NaOH")],
            [EquationTerm(1, "Na2SO4"), EquationTerm(2, "H2O")])
        XCTAssertTrue(neutralization.isAtomBalanced())

        let methane = Equation(
            [EquationTerm(1, "CH4", state: .gas), EquationTerm(2, "O2", state: .gas)],
            [EquationTerm(1, "CO2", state: .gas), EquationTerm(2, "H2O", state: .liquid)], condition: "点燃")
        XCTAssertTrue(methane.isAtomBalanced())
    }

    func testUnbalancedEquationDetected() {
        let wrong = Equation([EquationTerm(1, "H2"), EquationTerm(1, "O2")], [EquationTerm(1, "H2O")])
        XCTAssertFalse(wrong.isAtomBalanced())
        XCTAssertEqual(wrong.unbalancedElements, ["O"])
    }

    func testEquationDisplay() {
        let e = Equation(
            [EquationTerm(2, "NaOH"), EquationTerm(1, "CuSO4")],
            [EquationTerm(1, "Cu(OH)2", state: .solid), EquationTerm(1, "Na2SO4", state: .aqueous)])
        XCTAssertEqual(e.display, "2NaOH + CuSO₄ → Cu(OH)₂↓ + Na₂SO₄")

        let withCond = Equation([EquationTerm(1, "CaCO3")], [EquationTerm(1, "CaO"), EquationTerm(1, "CO2", state: .gas)], condition: "高温")
        XCTAssertEqual(withCond.display, "CaCO₃ —高温→ CaO + CO₂↑")
    }

    // MARK: 数学

    func testGcdLcm() {
        XCTAssertEqual(FormulaKit.gcd(12, 18), 6)
        XCTAssertEqual(FormulaKit.gcd(7, 3), 1)
        XCTAssertEqual(FormulaKit.lcm(2, 3), 6)
        XCTAssertEqual(FormulaKit.lcm(4, 6), 12)
        XCTAssertEqual(FormulaKit.lcm(3, 2), 6)
    }

    func testIonPolyatomic() {
        XCTAssertTrue(Ion(symbol: "SO4", charge: -2).isPolyatomic)
        XCTAssertTrue(Ion(symbol: "OH", charge: -1).isPolyatomic)
        XCTAssertFalse(Ion(symbol: "Cu", charge: 2).isPolyatomic)
        XCTAssertFalse(Ion(symbol: "S", charge: -2).isPolyatomic)
    }
}

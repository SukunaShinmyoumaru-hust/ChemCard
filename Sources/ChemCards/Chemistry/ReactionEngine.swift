import Foundation

/// 出牌合法性最终由 ReactionTable 这张表裁定；本文件保留「造表」用的推导逻辑。
/// 表优先，规则只是生成器：Resources/Data/reactions.json 改了立刻生效，推导代码不会绕过表参与判定。
enum ReactionEngine {

    /// 裁定：这两张牌能不能反应
    static func resolve(_ x: Species, _ y: Species) -> Reaction? {
        ReactionTable.reaction(x, y)
    }

    /// 推导：单层规则匹配，只被 `ReactionTable.generated()` 使用
    static func derive(_ x: Species, _ y: Species) -> Reaction? {
        // 精选表优先：有些对是被 BlockedReactions 挡掉的「假复分解」，正确写法就写在精选表里
        if let curated = CuratedReactions.lookup(x, y) { return curated }
        guard BlockedReactions.reason(x, y) == nil else { return nil }
        // 规范入参顺序，保证同一对物种永远生成同一个方程式字符串
        let (a, b) = Chemistry.ordered(x, y)
        for rule in ReactionRules.all {
            if let reaction = rule.apply(a, b) { return reaction }
            if let reaction = rule.apply(b, a) { return reaction }
        }
        return nil
    }

    static func reacts(_ x: Species, _ y: Species) -> Bool { resolve(x, y) != nil }

    /// 容器是混合物：最近倒进去的几种物质都还在，任意一种接得上就算打得出去。
    /// 从最新的一种开始配，横幅上的方程式才和玩家刚看到的那张牌对得上。
    static func resolve(anyOf contents: [Species], with candidate: Species) -> Reaction? {
        for species in contents.reversed() {
            if let reaction = resolve(species, candidate) { return reaction }
        }
        return nil
    }

    // MARK: 教学解释

    /// 为什么这张牌打不出去：容器是混合物，先报都有哪些物质，再给最新那一种的具体理由
    static func explain(contents: [Species], candidate: Species) -> String {
        guard let newest = contents.last else { return "反应容器里没有物质" }
        let reason = explain(top: newest, candidate: candidate)
        guard contents.count > 1 else { return reason }
        let names = contents.reversed().map(\.name).joined(separator: "、")
        return "\(candidate.name) 跟容器里的\(names)都不反应。最近倒入的那张：\(reason)"
    }

    /// 为什么这张牌打不出去
    static func explain(top: Species, candidate: Species) -> String {
        if let blocked = BlockedReactions.reason(top, candidate) { return blocked }

        let pair = [top, candidate]
        if let metal = pair.first(where: { $0.isMetal }),
           let acid = pair.first(where: { $0.isAcid && !$0.oxidizingAcid }),
           let symbol = metal.elementSymbol, !ActivitySeries.reactsWithAcid(symbol) {
            return "\(metal.name) 在金属活动性顺序中排在氢之后，不能置换\(acid.name)中的氢"
        }
        if let metal = pair.first(where: { $0.isMetal }),
           let salt = pair.first(where: { $0.isSalt }),
           let cation = salt.cation, let symbol = metal.elementSymbol,
           !ActivitySeries.reactsWithWater(symbol),
           !ActivitySeries.canDisplace(symbol, cation.symbol) {
            return "\(metal.name) 的活动性弱于\(salt.name)中的\(cation.symbol)，置换不发生"
        }
        if let metal = pair.first(where: { $0.isMetal }),
           let salt = pair.first(where: { $0.isSalt }),
           salt.cation.map({ ActivitySeries.reactsWithWater($0.symbol) }) == true {
            return "\(metal.name) 太活泼，投入\(salt.name)溶液会先与水反应，不属于盐的置换"
        }
        if isMetathesisPair(top, candidate) {
            return "两者交换成分后既没有沉淀、也没有气体或水生成，复分解反应不发生"
        }
        if top.category == candidate.category {
            return "\(top.name) 与 \(candidate.name) 同属\(top.category.displayName)，化学上不反应；同类别也不算打出，接不上就摸牌"
        }
        return "\(top.name) 与 \(candidate.name) 在通常条件下不发生反应"
    }

    /// 复分解型配对（酸/碱/盐之间）是否缺少反应驱动力
    private static func isMetathesisPair(_ x: Species, _ y: Species) -> Bool {
        let metathesisCapable: (Species) -> Bool = { $0.isAcid || ($0.isBase && $0.solubility == .soluble) || ($0.isSalt && $0.solubility == .soluble) }
        guard metathesisCapable(x), metathesisCapable(y) else { return false }
        guard let cationX = x.cation, let anionX = x.anion, let cationY = y.cation, let anionY = y.anion else { return false }
        let one = SolubilityTable.of(cation: cationX, anion: anionY)
        let two = SolubilityTable.of(cation: cationY, anion: anionX)
        return one != .insoluble && two != .insoluble
    }

    // MARK: 百科

    /// 反应手册：表里所有反应，按分值排序
    static func allReactions() -> [Reaction] {
        var seen = Set<String>()
        return ReactionTable.all().filter { seen.insert($0.displayEquation).inserted }
    }
}

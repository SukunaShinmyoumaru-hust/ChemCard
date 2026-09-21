import Foundation

/// 发牌：88 张化学牌 + 20 张功能牌 = 108 张，洗牌用定种子随机保证可复现
enum Deck {

    static let chemicalCardCount = 88
    static let actionCardCount = 20
    static let cardCount = chemicalCardCount + actionCardCount

    /// 双重份的核心物种：反应面广、容易接得上，多一张保证手感
    static let doubled: Set<String> = [
        "hcl", "h2so4", "naoh", "caoh2", "na2co3", "nahco3",
        "cuso4", "agno3", "o2", "h2o", "co2", "fe",
    ]

    /// 功能牌份数
    static let actionComposition: [(ActionCard, Int)] = [
        (.pump, 6), (.inert, 5), (.reversible, 4), (.assay, 5),
    ]

    static func copies(of species: Species) -> Int {
        doubled.contains(species.id) ? 2 : 1
    }

    static func chemicalSpecies() -> [Species] {
        Chemistry.all.flatMap { species in Array(repeating: species, count: copies(of: species)) }
    }

    /// uid 在未洗牌的顺序上分配，换种子只是换顺序，同一张牌永远是同一个 uid
    static func build(rng: inout SplitMix64) -> [Card] {
        var cards: [Card] = []
        for species in chemicalSpecies() {
            cards.append(Card(species: species, uid: cards.count))
        }
        for entry in actionComposition {
            for _ in 0..<entry.1 {
                cards.append(Card(action: entry.0, uid: cards.count))
            }
        }
        return cards.shuffled(using: &rng)
    }
}

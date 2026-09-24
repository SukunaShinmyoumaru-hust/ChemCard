import Foundation

/// 立绘气泡台词。台词按角色性格写，并带一点化学梗，让「电子手册」之外的教学氛围落在对白上。
enum PhraseBook {

    enum Moment: String, CaseIterable {
        case idle
        case play
        case bigPlay
        case drawn
        case passed        // 接不上、牌堆也空了，只能过这一手
        case pressed      // 被下家压住 / 被注液泵打中
        case illegal
        case win
        case lose
    }

    /// 取一句台词：优先角色专属，缺了就用通用兜底
    static func line(for character: CharacterID, _ moment: Moment, context: Context = Context()) -> String {
        let pool = lines[character]?[moment] ?? fallback[moment] ?? ["……"]
        let index = Int(abs(hash(character, moment, context.seed))) % pool.count
        return render(pool[index], context)
    }

    struct Context {
        var species: String = ""
        var equation: String = ""
        var seed: Int = 0

        init(species: String = "", equation: String = "", seed: Int = 0) {
            self.species = species
            self.equation = equation
            self.seed = seed
        }
    }

    private static func render(_ template: String, _ context: Context) -> String {
        template
            .replacingOccurrences(of: "{物质}", with: context.species.isEmpty ? "这张牌" : context.species)
            .replacingOccurrences(of: "{方程}", with: context.equation)
    }

    private static func hash(_ character: CharacterID, _ moment: Moment, _ seed: Int) -> Int {
        var value = seed &* 31
        for scalar in character.rawValue.unicodeScalars { value = value &* 131 &+ Int(scalar.value) }
        for scalar in moment.rawValue.unicodeScalars { value = value &* 131 &+ Int(scalar.value) }
        return value
    }

    private static let fallback: [Moment: [String]] = [
        .idle: ["反应容器很安静。", "下一手是什么呢。"],
        .play: ["打出{物质}。", "{方程}"],
        .bigPlay: ["这个反应很漂亮。", "现象齐全，教科书都不一定这么写。"],
        .drawn: ["摸一张看看。", "牌堆越来越薄了。"],
        .passed: ["接不上，先过。", "这手没有能反应的牌。"],
        .pressed: ["这一下不好接。", "先忍一手。"],
        .illegal: ["这两样东西不反应。", "放了会被弹回来的。"],
        .win: ["手牌出完了！"],
        .lose: ["这局先到这里。"]
    ]

    private static let lines: [CharacterID: [Moment: [String]]] = [
        .reimu: [
            .idle: ["赛钱箱空空如也，牌堆也空空如也。", "今天参拜的人一个都没有，打牌吧。", "灵体的直觉说，这张牌不能放。"],
            .play: ["封印一下——{物质}！"],
            .bigPlay: ["这个反应，净化得很彻底。", "赛钱箱都跟着亮了一下。"],
            .drawn: ["摸一张，飞天御币。"],
            .passed: ["这一手没有缘分，先过。"],
            .pressed: ["这种反应……有点棘手。", "被压住了，先退一步。"],
            .illegal: ["这个和容器里的东西不反应哦。"],
            .win: ["宴会开始！我先出完啦。"],
            .lose: ["嘛，改天再办一场。"]
        ],
        .marisa: [
            .idle: ["库，这就是魔法。", "让我算算这条规则的适用条件。", "普通的牌就够了！"],
            .play: ["魔法·{物质}！"],
            .bigPlay: ["这才叫普通的反应，不普通的现象。"],
            .drawn: ["收下了，这可不是借的。"],
            .passed: ["魔法也不是什么都溶得开的，过。"],
            .pressed: ["有意思，来硬的。"],
            .illegal: ["不反应就是不反应，我懂这个。"],
            .win: ["我赢了，规矩就是这样。"],
            .lose: ["下次连牌堆一起借走。"]
        ],
        .sanae: [
            .idle: ["风见神的加护，让牌堆听话一点。", "外面的世界管这个叫复分解。"],
            .play: ["奇迹——{物质}！"],
            .bigPlay: ["这就是奇迹，神明显灵了。"],
            .drawn: ["祝词一张。"],
            .passed: ["奇迹今天缺席，过一手。"],
            .pressed: ["这个组合我背过……不对。"],
            .illegal: ["强行凑反应是不行的。"],
            .win: ["守护表面的胜利！"],
            .lose: ["再来一次，这次一定有奇迹。"]
        ]
    ]
}
